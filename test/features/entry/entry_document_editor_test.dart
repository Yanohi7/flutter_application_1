import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/entry/presentation/widgets/entry_document_editor.dart';
import 'package:flutter_application_1/features/entry/presentation/widgets/entry_formatted_content.dart';

void main() {
  testWidgets(
    'Insert a table at the cursor, continue writing and retain order on reopening',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final title = TextEditingController(text: 'My note');
      final content = EntryDocumentController(text: 'BeforeAfter');
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),

          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                child: EntryDocumentEditor(
                  title: title,
                  content: content,
                  privateOpen: false,
                  onTogglePrivate: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('entry-content')));
      final field = tester
          .widget<TextField>(find.byKey(const Key('entry-content')))
          .controller!;
      field.selection = const TextSelection.collapsed(offset: 6);
      await tester.ensureVisible(find.byTooltip('Add table'));
      await tester.tap(find.byTooltip('Add table'));
      await tester.pumpAndSettle();
      final blocks = entryContentBlocks(content.text);
      expect(blocks.map((block) => block.structured), [false, true, false]);
      expect(blocks.first.content, 'Before');
      expect(blocks.last.content, 'After');
      expect(find.byType(Table), findsOneWidget);
      expect(find.byTooltip('Private information'), findsOneWidget);
      final saved = content.text;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),

          home: Scaffold(
            body: SingleChildScrollView(
              child: EntryDocumentView(content: saved),
            ),
          ),
        ),
      );
      expect(find.text('Before'), findsOneWidget);
      expect(find.text('After'), findsOneWidget);
      expect(find.byType(Table), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      title.dispose();
      content.dispose();
    },
  );

  testWidgets('Long cells widen, and adjacent blocks share a continuation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final title = TextEditingController(text: 'Note');
    final content = EntryDocumentController();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),

        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: EntryDocumentEditor(
              title: title,
              content: content,
              privateOpen: false,
              onTogglePrivate: () {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Add table'));
    await tester.pumpAndSettle();
    final table = find.byType(Table);
    final tableRows = tester.widget<Table>(table).children;
    final headerColor = (tableRows.first.decoration! as BoxDecoration).color!;
    final cellColor = (tableRows[1].decoration! as BoxDecoration).color!;
    expect(
      headerColor.computeLuminance(),
      lessThan(cellColor.computeLuminance()),
    );
    final header = find
        .descendant(of: table, matching: find.byType(TextFormField))
        .first;
    final before = tester.getSize(header).width;
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    await tester.enterText(
      header,
      'A long column heading that should stay completely readable',
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(header).width, greaterThan(before));
    expect(tester.getSize(table).width, greaterThan(320));
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    final addList = find.byTooltip('Add list');
    await tester.ensureVisible(addList);
    await tester.tap(addList);
    await tester.pumpAndSettle();
    expect(find.text('Continue writing…'), findsOneWidget);
    final blocks = entryContentBlocks(content.text);
    expect(blocks.where((block) => block.structured).length, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    title.dispose();
    content.dispose();
  });

  testWidgets(
    'The mobile selection toolbar copies text without changing the draft',
    (tester) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData')
            clipboard = (call.arguments as Map)['text'] as String;
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final title = TextEditingController(text: 'Note');
      final content = EntryDocumentController(text: 'Copy this text');
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),

          home: Scaffold(
            body: Form(
              child: EntryDocumentEditor(
                title: title,
                content: content,
                privateOpen: false,
                onTogglePrivate: () {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('entry-content')));
      final field = tester
          .widget<TextField>(find.byKey(const Key('entry-content')))
          .controller!;
      field.selection = const TextSelection(baseOffset: 0, extentOffset: 4);
      final editable = find.descendant(
        of: find.byKey(const Key('entry-content')),
        matching: find.byType(EditableText),
      );
      tester.state<EditableTextState>(editable).showToolbar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy').last);
      await tester.pumpAndSettle();
      expect(clipboard, 'Copy');
      expect(content.text, 'Copy this text');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      title.dispose();
      content.dispose();
    },
  );
}
