import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/category/domain/entities/entry_category.dart';
import 'package:flutter_application_1/features/category/domain/usecases/create_category.dart';
import 'package:flutter_application_1/features/category/domain/usecases/delete_category.dart';
import 'package:flutter_application_1/features/category/domain/usecases/get_categories.dart';
import 'package:flutter_application_1/features/category/domain/usecases/get_category_deletion_summary.dart';
import 'package:flutter_application_1/features/category/domain/usecases/update_category.dart';
import 'package:flutter_application_1/features/category/presentation/cubit/category_cubit.dart';
import 'package:flutter_application_1/features/category/presentation/pages/category_create_page.dart';
import 'package:flutter_application_1/features/category/presentation/widgets/category_picker.dart';

import '../../support/test_categories_repository.dart';

void main() {
  late CategoryCubit cubit;
  late TestCategoriesRepository repository;
  CategorySelection? result;

  Future<void> openPicker(WidgetTester tester) async {
    repository = TestCategoriesRepository();
    cubit = CategoryCubit(
      getCategories: GetCategories(repository),
      createCategory: CreateCategory(repository),
      updateCategory: UpdateCategory(repository),
      getCategoryDeletionSummary: GetCategoryDeletionSummary(repository),
      deleteCategory: DeleteCategory(repository),
    );
    addTearDown(cubit.close);
    await cubit.loadCategories();
    cubit.selectCategory(2);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),

          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showCategoryPicker(
                    context: context,
                    categories: cubit.state.categories,
                    onCreateCategory: (_) => showCategoryEditor(context),
                  );
                },
                child: const Text('Pick category'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pick category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create New Category'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Inline creation returns the saved category without changing background navigation',
    (tester) async {
      await openPicker(tester);
      expect(find.byType(Dialog), findsNWidgets(2));
      await tester.enterText(find.byType(TextFormField), '  Ideas  ');
      await tester.tap(find.text('Save category'));
      await tester.pumpAndSettle();
      expect(result?.category?.name, 'Ideas');
      expect(repository.categories.last.name, 'Ideas');
      expect(cubit.state.selectedCategoryId, 2);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Failed saves retain the draft; cancel and discard return to the picker',
    (tester) async {
      await openPicker(tester);
      repository.failSave = true;
      await tester.enterText(find.byType(TextFormField), 'Keep me');
      await tester.tap(find.text('Save category'));
      await tester.pumpAndSettle();
      expect(find.text('Keep me'), findsOneWidget);
      expect(repository.categories.length, 3);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Keep me'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Search categories'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Editor remains compact and scrollable above the keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await openPicker(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save category'));
    expect(tester.getRect(find.text('Save category')).bottom, lessThan(360));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Parent selection excludes the edited category and its descendants',
    (tester) async {
      await openPicker(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      final context = tester.element(find.text('Pick category'));
      showCategoryEditor(
        context,
        category: const EntryCategory(id: 2, name: 'Work'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('None (top level)'));
      await tester.pumpAndSettle();
      expect(
        find.text('Work'),
        findsOneWidget,
      ); // Only the draft name remains visible.
      expect(find.text('Projects'), findsNothing);
      expect(find.text('General'), findsOneWidget);
    },
  );
}
