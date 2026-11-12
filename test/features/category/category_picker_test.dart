import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/category/domain/entities/entry_category.dart';
import 'package:flutter_application_1/features/category/presentation/widgets/category_picker.dart';
import 'package:flutter_application_1/features/category/presentation/widgets/category_chip_row.dart';

const categories = [
  EntryCategory(id: 1, name: 'Work'),
  EntryCategory(id: 2, name: 'Projects', parentId: 1),
  EntryCategory(id: 3, name: 'Flutter', parentId: 2),
  EntryCategory(id: 4, name: 'Personal'),
  EntryCategory(id: 5, name: 'Projects', parentId: 4),
];

void main() {
  testWidgets('Collapsed tree expands recursively and can select a parent', (
    tester,
  ) async {
    CategorySelection? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showCategoryPicker(
                  context: context,
                  categories: categories,
                  allowTopLevel: true,
                );
              },
              child: const Text('Open picker'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    expect(find.text('Projects'), findsNothing);
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Flutter'), findsNothing);
    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    expect(find.text('Flutter'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('category-option-2')),
        matching: find.text('Select'),
      ),
    );
    await tester.pumpAndSettle();
    expect(result?.id, 2);
  });

  testWidgets(
    'Search exposes ancestor context and clearing restores collapse',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showCategoryPicker(
                  context: context,
                  categories: categories,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'flutter');
      await tester.pumpAndSettle();
      expect(find.text('Flutter'), findsOneWidget);
      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Personal'), findsNothing);
      await tester.tap(find.byTooltip('Clear category search'));
      await tester.pumpAndSettle();
      expect(find.text('Projects'), findsNothing);
      await tester.enterText(find.byType(TextField), 'not found');
      await tester.pumpAndSettle();
      expect(find.text('No categories found'), findsOneWidget);
    },
  );

  testWidgets('Top-level selection differs from dismissing the picker', (
    tester,
  ) async {
    CategorySelection? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showCategoryPicker(
                  context: context,
                  categories: categories,
                  allowTopLevel: true,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('None (top level)'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.id, isNull);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('Picker fits a narrow window with the keyboard visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showCategoryPicker(context: context, categories: categories),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Category row has no scrollbar and supports mouse dragging', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 260,
              child: CategoryChipRow(
                children: List.generate(
                  15,
                  (i) => ChoiceChip(
                    label: Text('Category $i'),
                    selected: false,
                    onSelected: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    final point = tester.getCenter(find.byType(CategoryChipRow));
    await tester.sendEventToBinding(
      PointerScrollEvent(position: point, scrollDelta: const Offset(0, 100)),
    );
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, 0);
    expect(find.byType(Scrollbar), findsNothing);
    final before = scrollable.position.pixels;
    final gesture = await tester.startGesture(
      point,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-70, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(before));
    expect(tester.takeException(), isNull);
  });
}
