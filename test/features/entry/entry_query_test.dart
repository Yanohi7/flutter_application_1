import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/entry/domain/entities/entry.dart';
import 'package:flutter_application_1/features/entry/domain/entities/media_attachment.dart';
import 'package:flutter_application_1/features/entry/presentation/widgets/entry_filter_sheet.dart';
import 'package:flutter_application_1/features/entry/presentation/widgets/entry_query.dart';

void main() {
  final now = DateTime(2026, 11, 10, 14);
  Entry note(
    int id, {
    String content = '',
    int category = 1,
    bool favorite = false,
    bool pinned = false,
    DateTime? date,
    String? attachment,
  }) => Entry(
    id: id,
    categoryId: category,
    title: ['Zulu', 'Alpha', 'Bravo', 'Delta'][id - 1],
    content: content,
    createdAt: date ?? now,
    updatedAt: now.add(Duration(minutes: id)),
    isFavorite: favorite,
    isPinned: pinned,
    attachments: attachment == null
        ? []
        : [
            MediaAttachment(
              fileType: attachment,
              fileName: 'file',
              localPath: '/fixture',
            ),
          ],
  );
  test(
    'Content filters recognize encoded checklists and every attachment type',
    () {
      final entries = [
        note(
          1,
          content: '::entry-checklist {"title":"Tasks","items":[{"text":"Buy milk","checked":false}]}',
        ),
        note(2, attachment: 'photo'),
        note(3, attachment: 'audio'),
        note(4, attachment: 'document'),
      ];
      for (final option in ['Checklist', 'Image', 'Audio', 'File'].indexed) {
        expect(
          queryEntries(
            entries,
            options: EntryViewOptions(content: option.$2),
          ).single.id,
          option.$1 + 1,
        );
      }
      expect(queryEntries(entries, query: 'buy milk').single.id, 1);
      expect(queryEntries(entries, query: 'checked'), isEmpty);
    },
  );
  test('Dates, category, favorites and sorting compose without losing pinned priority', () {
    final entries = [
      note(1, pinned: true),
      note(2, category: 2, favorite: true),
      note(3, date: DateTime(2026, 11, 9)),
      note(4, date: DateTime(2026, 10, 31)),
    ];
    expect(
      queryEntries(
        entries,
        options: const EntryViewOptions(time: 'Today'),
        now: now,
      ).map((e) => e.id),
      [1, 2],
    );
    expect(
      queryEntries(
        entries,
        options: const EntryViewOptions(time: 'This week'),
        now: now,
      ).length,
      3,
    );
    expect(
      queryEntries(
        entries,
        options: const EntryViewOptions(time: 'This month'),
        now: now,
      ).length,
      3,
    );
    expect(
      queryEntries(
        entries,
        categoryId: 1,
        favoritesOnly: true,
      ).map((e) => e.id),
      [1, 3, 4],
    );
    expect(queryEntries(entries, favoritesOnly: true).single.id, 2);
    expect(queryEntries(entries, categoryId: 1, query: 'alpha'), isEmpty);
    expect(
      queryEntries(
        entries,
        categoryId: 1,
        query: 'alpha',
        globalSearch: true,
      ).single.id,
      2,
    );
    expect(
      queryEntries(
        entries,
        options: const EntryViewOptions(sort: 'A–Z'),
      ).map((e) => e.id),
      [1, 2, 3, 4],
    );
    expect(
      queryEntries(
        entries,
        options: const EntryViewOptions(sort: 'Last edited'),
      ).map((e) => e.id),
      [1, 4, 3, 2],
    );
  });
}
