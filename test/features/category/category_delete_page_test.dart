import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/category/domain/entities/entry_category.dart';
import 'package:flutter_application_1/features/category/domain/repositories/categories_repository.dart';
import 'package:flutter_application_1/features/category/domain/results/category_deletion_summary.dart';
import 'package:flutter_application_1/features/category/domain/usecases/create_category.dart';
import 'package:flutter_application_1/features/category/domain/usecases/delete_category.dart';
import 'package:flutter_application_1/features/category/domain/usecases/get_categories.dart';
import 'package:flutter_application_1/features/category/domain/usecases/get_category_deletion_summary.dart';
import 'package:flutter_application_1/features/category/domain/usecases/update_category.dart';
import 'package:flutter_application_1/features/category/presentation/cubit/category_cubit.dart';
import 'package:flutter_application_1/features/category/presentation/pages/category_delete_page.dart';

class _Repository extends Fake implements CategoriesRepository {
  bool failSummary = false;
  int summaryCalls = 0;
  int deleteCalls = 0;

  @override
  Future<List<EntryCategory>> getCategories() async => const [
    EntryCategory(id: 1, name: 'Default', isDefault: true),
    EntryCategory(id: 2, name: 'Work'),
  ];

  @override
  Future<CategoryDeletionSummary> getDeletionSummary(int id) async {
    summaryCalls++;
    if (failSummary) throw StateError('Unavailable');
    return CategoryDeletionSummary(
      categoryId: id,
      descendantCategoryCount: 5,
      entryCount: 40,
    );
  }

  @override
  Future<void> deleteCategory(int id) async => deleteCalls++;
}

void main() {
  Future<_Repository> openPage(
    WidgetTester tester, {
    bool isDefault = false,
    bool failSummary = false,
  }) async {
    final repository = _Repository()..failSummary = failSummary;
    final cubit = CategoryCubit(
      getCategories: GetCategories(repository),
      createCategory: CreateCategory(repository),
      updateCategory: UpdateCategory(repository),
      getCategoryDeletionSummary: GetCategoryDeletionSummary(repository),
      deleteCategory: DeleteCategory(repository),
    );
    addTearDown(cubit.close);
    await cubit.loadCategories();
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),

          home: CategoryDeletePage(
            category: EntryCategory(
              id: isDefault ? 1 : 2,
              name: isDefault ? 'Default' : 'Work',
              isDefault: isDefault,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('Preview shows nested counts without deleting data', (
    tester,
  ) async {
    final repository = await openPage(tester);
    expect(find.text('5 subcategories'), findsOneWidget);
    expect(find.text('40 entries'), findsOneWidget);
    expect(repository.deleteCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed preview disables deletion and supports retry', (
    tester,
  ) async {
    final repository = await openPage(tester, failSummary: true);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    repository.failSummary = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('40 entries'), findsOneWidget);
    expect(repository.summaryCalls, 2);
    expect(repository.deleteCalls, 0);
  });

  testWidgets('Default category is protected even when opened directly', (
    tester,
  ) async {
    final repository = await openPage(tester, isDefault: true);
    expect(find.text('The default category cannot be deleted'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(repository.summaryCalls, 0);
    expect(repository.deleteCalls, 0);
  });
}
