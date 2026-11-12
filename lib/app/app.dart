// Connect repository implementations, use cases and Cubits, then apply the selected app appearance

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart' show ChangeNotifierProvider;

import '../core/database/database_helper.dart';
import '../core/theme/app_theme.dart';

import '../features/category/data/datasources/category_local_datasource.dart';
import '../features/category/data/repositories/categories_repository_impl.dart';

import '../features/category/domain/repositories/categories_repository.dart';
import '../features/category/domain/usecases/get_categories.dart';
import '../features/category/domain/usecases/create_category.dart';
import '../features/category/domain/usecases/update_category.dart';
import '../features/category/domain/usecases/get_category_deletion_summary.dart';
import '../features/category/domain/usecases/delete_category.dart';
import '../features/onboarding/domain/repositories/onboarding_repository.dart';
import '../features/onboarding/data/repositories/onboarding_repository_impl.dart';
import '../features/onboarding/presentation/cubit/onboarding_cubit.dart';
import '../features/onboarding/presentation/cubit/onboarding_state.dart';
import '../features/onboarding/presentation/screens/onboarding_screen.dart';

import '../features/category/presentation/cubit/category_cubit.dart';

import '../features/entry/data/datasources/entry_local_datasource.dart';
import '../features/entry/data/repositories/entry_repository_impl.dart';
import '../features/entry/domain/repositories/entries_repository.dart';
import '../features/entry/domain/usecases/create_entry.dart';
import '../features/entry/domain/usecases/delete_entry.dart';
import '../features/entry/domain/usecases/get_entries.dart';
import '../features/entry/domain/usecases/update_entry.dart';
import '../features/entry/presentation/cubit/entry_cubit.dart';
import '../features/entry/presentation/entry_playback.dart';
import '../features/entry/presentation/pages/home_page.dart';
import '../features/entry/presentation/widgets/entry_audio_player.dart';
import '../features/profile/data/profile_store.dart';
import '../features/cloud_sync/presentation/cloud_sync_controller.dart';
import '../features/cloud_sync/presentation/cloud_sync_home.dart';
import '../core/presentation/app_preferences.dart';
import '../core/presentation/widgets/app_background.dart';

/// Composition root: connect data, domain and presentation
class MyApp extends StatelessWidget {
  final EntriesRepository?
  entriesRepository; // We can use another DB for testing
  final CategoriesRepository? categoriesRepository;
  final DatabaseHelper? database;
  final ProfileStore? profile;
  final CloudSyncController? cloudSync;
  final bool repeatOnboarding;
  final OnboardingRepository? onboardingRepository;

  const MyApp({
    super.key,
    this.entriesRepository,
    this.categoriesRepository,
    this.database,
    this.profile,
    this.cloudSync,
    this.repeatOnboarding = false,
    this.onboardingRepository,
  });

  @override
  Widget build(BuildContext context) {
    final localDatabase = database ?? DatabaseHelper.instance;
    // Create concrete data repositories here so domain use cases only depend on contracts
    return MultiRepositoryProvider(
      providers: [
        ChangeNotifierProvider<EntryPlayback>(create: (_) => EntryPlayback()),
        ChangeNotifierProvider<ProfileStore?>.value(value: profile),
        ChangeNotifierProvider<CloudSyncController?>.value(value: cloudSync),
        RepositoryProvider<OnboardingRepository>(
          create: (_) =>
              onboardingRepository ??
              OnboardingRepositoryImpl(repeat: repeatOnboarding),
        ),

        RepositoryProvider<EntriesRepository>(
          create: (_) =>
              entriesRepository ??
              EntryRepositoryImpl(EntryLocalDataSourceImpl(localDatabase)),
        ),

        RepositoryProvider<CategoriesRepository>(
          create: (_) =>
              categoriesRepository ??
              CategoriesRepositoryImpl(CategoryLocalDataSource(localDatabase)),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<OnboardingCubit>(
            create: (context) =>
                OnboardingCubit(context.read<OnboardingRepository>())..load(),
          ),

          BlocProvider<EntryCubit>(
            create: (context) {
              final repo = context.read<EntriesRepository>(); // Repository
              return EntryCubit(
                getEntries: GetEntries(repo),
                createEntry: CreateEntry(repo),
                updateEntry: UpdateEntry(repo),
                deleteEntry: DeleteEntry(repo),
              )..loadEntries(); // First load when opening the app
            },
          ),

          BlocProvider<CategoryCubit>(
            create: (context) {
              final repo = context.read<CategoriesRepository>(); // Repository
              return CategoryCubit(
                getCategories: GetCategories(repo),
                createCategory: CreateCategory(repo),
                updateCategory: UpdateCategory(repo),
                getCategoryDeletionSummary: GetCategoryDeletionSummary(repo),
                deleteCategory: DeleteCategory(repo),
              )..loadCategories(); // First load when opening the app
            },
          ),
        ],
        // Rebuild MaterialApp when saved appearance or Premium access changes
        child: ListenableBuilder(
          listenable: appPreferences,
          child: BlocConsumer<OnboardingCubit, OnboardingState>(
            // Report persistence problems without reopening the completed tutorial
            listener: (context, state) {
              if (state.status == OnboardingStatus.completed &&
                  state.errorMessage != null) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(state.errorMessage!)));
              }
            },
            builder: (context, state) {
              // Wait for preferences before choosing the first screen
              if (state.status == OnboardingStatus.checking) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (state.status == OnboardingStatus.failure) {
                return Scaffold(
                  body: SafeArea(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.errorMessage ?? 'Could not open the app.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: context.read<OnboardingCubit>().load,
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              if (state.status == OnboardingStatus.completed) {
                return const CloudSyncHome(child: HomePage());
              }

              return const OnboardingScreen();
            },
          ),
          // Apply the same coordinated palette to every route in both modes
          builder: (_, child) => MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Entries',
            locale: const Locale('en'),
            theme: AppTheme.build(
              Brightness.light,
              palette: appPreferences.palette,
              surfaceOpacity: appPreferences.surfaceOpacity,
            ).copyWith(scaffoldBackgroundColor: Colors.transparent),
            darkTheme: AppTheme.build(
              Brightness.dark,
              palette: appPreferences.palette,
              surfaceOpacity: appPreferences.surfaceOpacity,
            ).copyWith(scaffoldBackgroundColor: Colors.transparent),
            themeMode: appPreferences.mode,
            builder: (context, navigator) => EntryPlaybackObserver(
              child: AppBackground(child: navigator ?? const SizedBox.shrink()),
            ),
            home: child,
          ),
        ),
      ),
    );
  }
}
