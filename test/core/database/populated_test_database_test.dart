import 'dart:io';

import 'package:flutter_application_1/core/database/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
    'The populated test database opens with the current app schema',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final directory = await Directory.systemTemp.createTemp(
        'entries_fixture_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = await File('test/data/entries_test.db')
          .copy(p.join(directory.path, 'entries_test.db'));
      final helper = DatabaseHelper.forTesting(file.path);
      addTearDown(helper.close);
      final database = await helper.database;
      final categories = await database.query('categories');
      final notes = await database.query('entries');
      expect(
        categories.map((item) => item['name']),
        containsAll(['English', 'Українська', 'Рецепти']),
      );
      expect(notes, hasLength(greaterThanOrEqualTo(45)));
      expect(
        notes.map((item) => item['title']),
        containsAll([
          'Saturday reset',
          'Борщ із квасолею',
          'Слова для подорожі',
        ]),
      );
      final byId = {
        for (final category in categories) category['id']: category,
      };
      expect(
        categories.any((item) => byId[item['parent_id']]?['parent_id'] != null),
        isTrue,
      );
      expect(
        notes.any((note) => note['is_pinned'] == 1 && note['is_favorite'] == 1),
        isTrue,
      );
      expect(
        notes.any(
          (note) => (note['content'] as String).contains('::entry-table '),
        ),
        isTrue,
      );
      expect(await database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );
}
