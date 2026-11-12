import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/app/app.dart';
import 'package:flutter_application_1/features/entry/presentation/pages/notifiers.dart';
import 'package:flutter_application_1/features/entry/presentation/widgets/entry_card.dart';
import 'package:flutter_application_1/features/category/domain/entities/entry_category.dart';
import 'package:flutter_application_1/features/category/domain/repositories/categories_repository.dart';
import 'package:flutter_application_1/features/onboarding/domain/repositories/onboarding_repository.dart';

import 'support/test_entries_repository.dart';

void main() {
  setUp(() => isDarkModeNotifier.value = false);

  Future<void> openApp(WidgetTester tester, TestEntriesRepository repo) async {
    tester.view.physicalSize = const Size(
      390,
      844,
    ); // A typical phone viewport.
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MyApp(
        entriesRepository: repo,
        categoriesRepository: _TestCategoriesRepository(),
        onboardingRepository: _CompletedOnboarding(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openEditor(WidgetTester tester) async {
    await tester.tap(find.byTooltip('New'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'New entry'));
    await tester.pumpAndSettle();
  }

  Future<Finder> revealSave(WidgetTester tester) async {
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.scrollUntilVisible(
      save,
      220,
      scrollable: find
          .descendant(of: find.byType(Form), matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    return save;
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(await revealSave(tester));
  }

  testWidgets('First entry: validate, save, open, and edit', (tester) async {
    final repo = TestEntriesRepository();
    await openApp(tester, repo);
    expect(find.text('Start with your first entry'), findsOneWidget);
    await openEditor(tester);
    await tapSave(tester);
    await tester.pumpAndSettle();
    expect(find.text('Enter an entry title'), findsOneWidget);
    expect(repo.entries, isEmpty);
    await tester.enterText(
      find.byKey(const Key('entry-title')),
      'My first entry',
    );
    await tester.enterText(
      find.byKey(const Key('entry-content')),
      'This text should be saved.',
    );
    await tapSave(tester);
    await tester.pumpAndSettle();
    expect(find.byType(EntryCard), findsOneWidget);
    expect(repo.entries.single.content, 'This text should be saved.');
    await tester.tap(find.text('My first entry'));
    await tester.pumpAndSettle();
    expect(find.text('This text should be saved.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('entry-content')),
      'Updated text',
    );
    await tester.tap(find.byTooltip('Reading mode'));
    await tester.pumpAndSettle();
    expect(repo.entries.length, 1); // Editing does not create a duplicate.
    expect(repo.entries.single.content, 'Updated text');
    expect(find.byKey(const Key('entry-content')), findsNothing);
    expect(find.byKey(const Key('entry-title')), findsNothing);
    expect(find.text('Updated text'), findsOneWidget);
    for (final label in ['Gallery', 'Add audio', 'Add files']) {
      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, label),
      );
      expect(button.onPressed, isNotNull);
    }
    await tester.tap(find.byTooltip('Exit reading mode'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('entry-content')),
      'Edited again',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Save changes'));
    await tester.pumpAndSettle();
    expect(repo.entries.single.content, 'Edited again');
    expect(find.byKey(const Key('entry-content')), findsOneWidget);
  });

  testWidgets('A save failure preserves text and allows retrying', (
    tester,
  ) async {
    final repo = TestEntriesRepository()..failSave = true;
    await openApp(tester, repo);
    await openEditor(tester);
    await tester.enterText(find.byKey(const Key('entry-title')), 'Draft');
    await tester.enterText(
      find.byKey(const Key('entry-content')),
      'Keep this text',
    );
    await tapSave(tester);
    await tester.pumpAndSettle();
    expect(find.text('Keep this text'), findsOneWidget);
    expect(repo.entries, isEmpty);
    repo.failSave = false;
    await tapSave(tester);
    await tester.pumpAndSettle();
    expect(repo.entries.single.content, 'Keep this text');
  });

  testWidgets('Reading actions keep the toolbar stable while a flag is saved', (
    tester,
  ) async {
    final entry = sampleEntry(1);
    final repo = TestEntriesRepository([entry]);
    await openApp(tester, repo);
    await tester.tap(find.text(entry.title!));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reading mode'));
    await tester.pumpAndSettle();

    final menu = find.byTooltip('Entry actions');
    final menuCenter = tester.getCenter(menu);
    final save = find.byTooltip('Save changes').hitTestable();
    expect(save, findsNothing);
    repo.pendingSave = Completer<void>();
    await tester.tap(find.byTooltip('Add to favorites'));
    await tester.pump();
    expect(save, findsNothing);
    expect(tester.getCenter(menu), menuCenter);
    repo.pendingSave!.complete();
    await tester.pumpAndSettle();
    expect(repo.entries.single.isFavorite, isTrue);
    expect(tester.getCenter(menu), menuCenter);

    await tester.tap(find.byTooltip('Pin'));
    await tester.pumpAndSettle();
    expect(repo.entries.single.isPinned, isTrue);
    expect(repo.entries.single.updatedAt, entry.updatedAt);
    expect(find.byTooltip('Exit reading mode'), findsOneWidget);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.text('Duplicate'), findsOneWidget);
  });

  testWidgets('A slow save does not create a duplicate', (tester) async {
    final repo = TestEntriesRepository()..pendingSave = Completer<void>();
    await openApp(tester, repo);
    await openEditor(tester);
    await tester.enterText(find.byKey(const Key('entry-title')), 'One entry');
    await tapSave(tester);
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);
    await tester.tap(find.text('Saving…'), warnIfMissed: false);
    await tester.pump();
    expect(repo.createCalls, 1);
    repo.pendingSave!.complete();
    await tester.pumpAndSettle();
    expect(repo.entries.length, 1);
  });

  testWidgets('Back asks about unsaved changes and allows continuing', (
    tester,
  ) async {
    await openApp(tester, TestEntriesRepository());
    await openEditor(tester);
    await tester.enterText(
      find.byKey(const Key('entry-title')),
      'Do not erase',
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Do not erase'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.text('Start with your first entry'), findsOneWidget);
  });

  testWidgets('Favorites, search, and deletion with confirmation', (
    tester,
  ) async {
    final repo = TestEntriesRepository([sampleEntry(1), sampleEntry(2)]);
    await openApp(tester, repo);
    await tester.tap(find.byTooltip('Add to favorites').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    expect(find.byType(EntryCard), findsOneWidget);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'no matching text');
    await tester.pumpAndSettle();
    expect(find.text('No search results'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Entry actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.entries.length, 2);
    await tester.tap(find.byTooltip('Entry actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(repo.entries.length, 1);
  });

  testWidgets('A load failure allows retrying', (tester) async {
    final repo = TestEntriesRepository()..failLoad = true;
    await openApp(tester, repo);
    expect(find.text('Try again'), findsOneWidget);
    repo.failLoad = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Start with your first entry'), findsOneWidget);
  });

  testWidgets(
    'The grid supports different widths, larger text, and dark mode',
    (tester) async {
      await openApp(
        tester,
        TestEntriesRepository(List.generate(12, (i) => sampleEntry(i + 1))),
      );
      for (final width in [320.0, 390.0, 768.0, 1200.0]) {
        tester.view.physicalSize = Size(width, 844);
        await tester.pumpAndSettle();
        final cards = find.byType(EntryCard);
        final firstRowY = tester.getTopLeft(cards.first).dy;
        expect(
          tester
              .widgetList<EntryCard>(cards)
              .where(
                (card) =>
                    tester.getTopLeft(find.byKey(card.key!)).dy == firstRowY,
              )
              .length,
          width == 320
              ? 1
              : width == 390
              ? 2
              : 4,
        );
        expect(
          tester.takeException(),
          isNull,
        ); // Including RenderFlex overflow errors.
      }
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      isDarkModeNotifier.value = true;
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await openEditor(tester);
      tester.view.viewInsets = const FakeViewPadding(
        bottom: 260,
      ); // Simulate the keyboard.
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final saveButton = await revealSave(tester);
      final save = tester.getRect(saveButton);
      expect(
        save.bottom,
        lessThanOrEqualTo(380),
      ); // The button stays above the keyboard.
    },
  );
}

class _CompletedOnboarding implements OnboardingRepository {
  @override
  Future<bool> isOnboardingComplete() async => true;

  @override
  Future<void> setOnboardingComplete() async {}
}

class _TestCategoriesRepository extends Fake implements CategoriesRepository {
  @override
  Future<List<EntryCategory>> getCategories() async {
    return const [EntryCategory(id: 1, name: 'General', isDefault: true)];
  }
}
