import 'package:flutter_application_1/core/database/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late DatabaseHelper helper;
  late Database db;
  late int defaultId;
  const date = '2026-11-11T09:00:00Z';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    helper = DatabaseHelper.forTesting(inMemoryDatabasePath);
    defaultId = await helper.ensureDefaultCategory();
    db = await helper.database;
  });
  tearDown(() => helper.close());

  test('Only active workspace tables are created', () async {
    final tables = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: "type = 'table' AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata'",
    );
    expect(
      tables.map((row) => row['name']),
      unorderedEquals([
        'users',
        'profiles',
        'categories',
        'entries',
        'media_attachments',
      ]),
    );
    expect(await helper.ensureDefaultCategory(), defaultId);
    expect(await db.query('profiles'), hasLength(1));
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });

  test('Category names are unique within the same parent', () async {
    final owner = (await db.query('users')).single['id'];
    Future<int> category(String name, {int? parent, bool isDefault = false}) =>
        db.insert('categories', {
          'user_id': owner,
          'name': name,
          'parent_id': parent,
          'is_default': isDefault ? 1 : 0,
          'created_at': date,
          'updated_at': date,
        });

    final work = await category('Work');
    final personal = await category('Personal');
    await category('Projects', parent: work);
    await category('Projects', parent: personal);
    await expectLater(
      category('Projects', parent: work),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(category('Work'), throwsA(isA<DatabaseException>()));
    await expectLater(
      category('Another default', isDefault: true),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('Entry protects its category and owns its attachments', () async {
    final entry = await db.insert('entries', {
      'category_id': defaultId,
      'title': 'Weekend plans',
      'content': 'Prepare a camera',
      'created_at': date,
      'updated_at': date,
    });
    await db.insert('media_attachments', {
      'entry_id': entry,
      'file_type': 'photo',
      'file_name': 'camera.png',
      'local_path': 'camera.png',
      'created_at': date,
    });
    await expectLater(
      db.delete('categories'),
      throwsA(isA<DatabaseException>()),
    );
    await db.delete('entries');
    expect(await db.query('media_attachments'), isEmpty);
  });
}
