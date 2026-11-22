import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/entry/domain/entities/entry.dart';
import 'package:flutter_application_1/features/entry/domain/entities/media_attachment.dart';
import 'package:flutter_application_1/features/entry/presentation/widgets/entry_filter_sheet.dart';
import 'package:flutter_application_1/features/entry/presentation/widgets/entry_query.dart';

const _checklist =
    '::entry-checklist {"title":"Tasks","items":[{"text":"Buy milk","checked":false}]}';

void main() {
  test('UT-01 Searches titles regardless of case and surrounding spaces', () {
    final entries = [_note(1, title: 'Alpha plan'), _note(2, title: 'Beta')];

    expect(queryEntries(entries, query: '  ALPHA  ').map((entry) => entry.id), [
      1,
    ]);
  });

  test('UT-02 Searches checklist text without matching internal JSON keys', () {
    final entries = [_note(1, content: _checklist), _note(2, content: 'Bread')];

    expect(queryEntries(entries, query: 'Buy milk').single.id, 1);
    expect(queryEntries(entries, query: 'checked'), isEmpty);
  });

  test('UT-03 Global search can find notes outside the current category', () {
    final entries = [
      _note(1, title: 'Project plan', category: 1),
      _note(2, title: 'Project budget', category: 2),
    ];

    expect(
      queryEntries(entries, categoryId: 1, query: 'project').single.id,
      1,
    );
    expect(
      queryEntries(
        entries,
        categoryId: 1,
        query: 'project',
        globalSearch: true,
      ).map((entry) => entry.id),
      unorderedEquals([1, 2]),
    );
  });

  test('UT-04 Favorites and category views return their own notes', () {
    final entries = [
      _note(1, category: 1),
      _note(2, category: 2, favorite: true),
      _note(3, category: 1, favorite: true),
    ];

    expect(
      queryEntries(entries, favoritesOnly: true).map((entry) => entry.id),
      unorderedEquals([2, 3]),
    );
    expect(
      queryEntries(entries, categoryId: 1, favoritesOnly: true)
          .map((entry) => entry.id),
      unorderedEquals([1, 3]),
    );
  });

  test('UT-05 Checklist filter keeps notes with a checklist block', () {
    final entries = [
      _note(1, content: _checklist),
      _note(2, content: 'Buy milk'),
    ];

    final result = queryEntries(
      entries,
      options: const EntryViewOptions(content: 'Checklist'),
    );

    expect(result.single.id, 1);
  });

  test('UT-06 Image, audio, and file filters match their attachment types', () {
    final entries = [
      _note(1, attachment: 'photo'),
      _note(2, attachment: 'audio'),
      _note(3, attachment: 'document'),
      _note(4),
    ];

    for (final (filter, id) in [('Image', 1), ('Audio', 2), ('File', 3)]) {
      final result = queryEntries(
        entries,
        options: EntryViewOptions(content: filter),
      );

      expect(result.map((entry) => entry.id), [id], reason: filter);
    }
  });

  test('UT-07 Today includes this midnight and excludes the next one', () {
    final entries = [
      _note(1, date: DateTime(2026, 11, 9, 23, 59)),
      _note(2, date: DateTime(2026, 11, 10)),
      _note(3, date: DateTime(2026, 11, 10, 23, 59)),
      _note(4, date: DateTime(2026, 11, 11)),
    ];

    final result = queryEntries(
      entries,
      options: const EntryViewOptions(time: 'Today'),
      now: DateTime(2026, 11, 10, 14),
    );

    expect(result.map((entry) => entry.id), unorderedEquals([2, 3]));
  });

  test('UT-08 Week and month filters apply their calendar boundaries', () {
    final entries = [
      _note(1, date: DateTime(2026, 10, 31, 23, 59)),
      _note(2, date: DateTime(2026, 11, 8, 23, 59)),
      _note(3, date: DateTime(2026, 11, 9)),
      _note(4, date: DateTime(2026, 11, 15, 23, 59)),
      _note(5, date: DateTime(2026, 11, 16)),
      _note(6, date: DateTime(2026, 12, 1)),
    ];
    final now = DateTime(2026, 11, 10, 14);

    expect(
      queryEntries(entries, options: const EntryViewOptions(time: 'This week'), now: now)
          .map((entry) => entry.id),
      unorderedEquals([3, 4]),
    );
    expect(
      queryEntries(entries, options: const EntryViewOptions(time: 'This month'), now: now)
          .map((entry) => entry.id),
      unorderedEquals([2, 3, 4, 5]),
    );
  });

  test('UT-09 Alphabetical sort keeps pinned notes first', () {
    final entries = [
      _note(3, title: 'Bravo'),
      _note(1, title: 'Zulu', pinned: true),
      _note(2, title: 'alpha'),
    ];

    final result = queryEntries(
      entries,
      options: const EntryViewOptions(sort: 'A-Z'),
    );

    expect(result.map((entry) => entry.id), [1, 2, 3]);
  });

  test('UT-10 Last edited sort uses update time after pinned priority', () {
    final entries = [
      _note(1, pinned: true, updatedAt: DateTime(2026, 11, 10, 1)),
      _note(2, date: DateTime(2026, 11, 10), updatedAt: DateTime(2026, 11, 10, 2)),
      _note(3, date: DateTime(2026, 11, 9), updatedAt: DateTime(2026, 11, 10, 3)),
    ];

    final result = queryEntries(
      entries,
      options: const EntryViewOptions(sort: 'Last edited'),
    );

    expect(result.map((entry) => entry.id), [1, 3, 2]);
  });
}

Entry _note(
  int id, {
  String title = 'Note',
  String content = '',
  int category = 1,
  bool favorite = false,
  bool pinned = false,
  DateTime? date,
  DateTime? updatedAt,
  String? attachment,
}) {
  final createdAt = date ?? DateTime(2026, 11, 10);
  return Entry(
    id: id,
    categoryId: category,
    title: title,
    content: content,
    createdAt: createdAt,
    updatedAt: updatedAt ?? createdAt,
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
}
