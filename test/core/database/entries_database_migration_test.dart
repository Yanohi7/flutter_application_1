import 'dart:io';

import 'package:flutter_application_1/core/database/database_helper.dart';
import 'package:flutter_application_1/core/database/entries_database_migration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory folder;
  late String oldPath;
  late String destination;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('entries_migration_test_');
    oldPath = p.join(folder.path, 'project', 'test_database.db');
    destination = p.join(folder.path, 'support', 'entries.db');
    addTearDown(() => folder.delete(recursive: true));
  });

  Future<void> createLegacy(String path, {String? title}) async {
    final helper = DatabaseHelper.forTesting(path);
    try {
      final category = await helper.ensureDefaultCategory();
      if (title == null) return;
      final database = await helper.database;
      final id = await database.insert('entries', {
        'category_id': category,
        'title': title,
        'content': 'Original body',
        'private_content': 'encrypted-fixture',
        'created_at': '2026-10-14T12:00:00',
        'updated_at': '2026-10-14T12:00:00',
        'is_pinned': 1,
        'is_favorite': 1,
      });
      await database.insert('media_attachments', {
        'entry_id': id,
        'file_type': 'photo',
        'file_name': 'original.png',
        'local_path': p.join(folder.path, 'media', 'original.png'),
        'created_at': '2026-10-14T12:00:00',
      });
    } finally {
      await helper.close();
    }
  }

  test(
    'Migrates the populated copy and retains the original database',
    () async {
      final emptyPath = p.join(folder.path, 'runner', 'test_database.db');
      await createLegacy(emptyPath);
      await createLegacy(oldPath, title: 'Existing note');

      expect(
        await prepareEntriesDatabase(
          destination: destination,
          legacyPaths: [emptyPath, oldPath],
        ),
        destination,
      );

      final migrated = DatabaseHelper.forTesting(destination);
      try {
        final database = await migrated.database;
        final note = (await database.query('entries')).single;
        expect(note['title'], 'Existing note');
        expect(note['content'], 'Original body');
        expect(note['private_content'], 'encrypted-fixture');
        expect(note['is_pinned'], 1);
        expect(note['is_favorite'], 1);
        expect(
          (await database.query('media_attachments')).single['entry_id'],
          note['id'],
        );
        expect(await database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        await database.update('entries', {'title': 'Updated after migration'});
        await prepareEntriesDatabase(
          destination: destination,
          legacyPaths: [oldPath],
        );
        expect(
          (await database.query('entries')).single['title'],
          'Updated after migration',
        );
      } finally {
        await migrated.close();
      }
      final original = await openReadOnlyDatabase(oldPath);
      try {
        expect(
          (await original.query('entries')).single['title'],
          'Existing note',
        );
      } finally {
        await original.close();
      }
    },
  );

  test('Two populated legacy files remain intact when their ownership is ambiguous', () async {
    final otherPath = p.join(folder.path, 'runner', 'test_database.db');
    await createLegacy(oldPath, title: 'First note');
    await createLegacy(otherPath, title: 'Second note');
    await expectLater(
      prepareEntriesDatabase(
        destination: destination,
        legacyPaths: [oldPath, otherPath],
      ),
      throwsStateError,
    );
    expect(await File(destination).exists(), isFalse);
    expect(await File(oldPath).exists(), isTrue);
    expect(await File(otherPath).exists(), isTrue);
  });
}
