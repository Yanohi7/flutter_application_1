import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/presentation/app_preferences.dart';
import 'package:flutter_application_1/core/utils/datetime_helpers.dart';
import 'package:flutter_application_1/features/entry/domain/entities/media_attachment.dart';
import 'package:flutter_application_1/features/entry/presentation/widgets/entries_grid.dart';
import 'package:flutter_application_1/features/entry/presentation/widgets/entry_card.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_entries_repository.dart';

void main() {
  testWidgets(
    'Only the section has a divider and all card footer icons align',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 650);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final entry = sampleEntry(1, pinned: true, favorite: true).copyWith(
        attachments: [
          for (final type in ['photo', 'document', 'audio'])
            MediaAttachment(fileType: type, fileName: type, localPath: type),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                EntriesGrid(
                  entries: [entry, sampleEntry(2)],
                  enabled: true,
                  cardSize: NoteCardSize.compact,
                  onOpen: (_) {},
                  onPin: (_) {},
                  onFavorite: (_) {},
                  onActions: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Pinned'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
      final date = tester.getCenter(
        find.byTooltip(formatEntryDate(entry.createdAt)).first,
      );
      for (final label in [
        'Files',
        'Audio',
        'Images',
        'Remove from favorites',
        'Unpin',
      ]) {
        expect(tester.getCenter(find.byTooltip(label)).dy, closeTo(date.dy, 1));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Note sizes change card density at phone and desktop widths', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final (width, columns) in [
      (320.0, [2, 1, 1]),
      (1100.0, [6, 4, 3]),
    ]) {
      tester.view.physicalSize = Size(width, 650);
      for (final (index, size) in NoteCardSize.values.indexed) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CustomScrollView(
                slivers: [
                  EntriesGrid(
                    entries: [for (var id = 1; id <= 7; id++) sampleEntry(id)],
                    enabled: true,
                    cardSize: size,
                    onOpen: (_) {},
                    onPin: (_) {},
                    onFavorite: (_) {},
                    onActions: (_) {},
                  ),
                ],
              ),
            ),
          ),
        );
        final cards = find.byType(EntryCard);
        final firstRowY = tester.getTopLeft(cards.first).dy;
        final firstRowCount = tester
            .widgetList<EntryCard>(cards)
            .where(
              (card) =>
                  tester.getTopLeft(find.byKey(card.key!)).dy == firstRowY,
            )
            .length;
        expect(firstRowCount, columns[index], reason: size.label);
        expect(tester.takeException(), isNull);
      }
    }
  });
}
