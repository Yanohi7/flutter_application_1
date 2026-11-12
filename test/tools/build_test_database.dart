import 'dart:io';

import 'package:flutter_application_1/core/database/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/populate_test_database.dart';

void main() {
  test('Create the populated SQLite test database', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final target = File(p.absolute('test/data/entries_test.db'));
    if (await target.exists() &&
        !const bool.fromEnvironment('REPLACE_TEST_DATABASE')) {
      fail(
        'The sample database already exists. Use REPLACE_TEST_DATABASE to rebuild it.',
      );
    }

    await target.parent.create(recursive: true);
    final staging = await target.parent.createTemp('entries_test_');
    final path = p.join(staging.path, 'entries_test.db');
    final helper = DatabaseHelper.forTesting(path);
    try {
      final database = await helper.database;
      await populateTestDatabase(
        database,
        mediaDirectory: Directory(p.join('test', 'data', 'media')),
        photo: await File('assets/images/spiderman-bg.jpg').readAsBytes(),
      );
      expect(await database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      await helper.close();
      await File(path).rename(target.path);
    } finally {
      await helper.close();
      if (await File(path).exists()) await deleteDatabase(path);
      await staging.delete();
    }
  });
}
