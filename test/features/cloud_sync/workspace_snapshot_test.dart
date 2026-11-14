import 'dart:io';

import 'package:flutter_application_1/core/database/database_helper.dart';
import 'package:flutter_application_1/features/cloud_sync/data/local_workspace_snapshot.dart';
import 'package:flutter_application_1/features/entry/data/datasources/entry_local_datasource.dart';
import 'package:flutter_application_1/features/entry/presentation/widgets/entry_formatted_content.dart';
import 'package:flutter_application_1/features/profile/data/profile_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/populate_test_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Restore the test workspace on a different device path', () async {
    final directory = await Directory.systemTemp.createTemp(
      'entries-transfer-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final source = DatabaseHelper.forTesting(
      p.join(directory.path, 'source.db'),
    );
    final target = DatabaseHelper.forTesting(
      p.join(directory.path, 'target.db'),
    );
    addTearDown(source.close);
    addTearDown(target.close);
    final sourceFiles = Directory(p.join(directory.path, 'source-files'));
    final targetFiles = Directory(p.join(directory.path, 'target-files'));
    final photo = await File('assets/images/spiderman-bg.jpg').readAsBytes();
    await populateTestDatabase(
      await source.database,
      mediaDirectory: sourceFiles,
      photo: photo,
      privateContent: 'opaque-encrypted-payload',
    );
    final original = await ProfileStore.writeOriginal(sourceFiles, photo);
    await (await source.database).update('profiles', {
      'avatar_original_path': original,
      'avatar_image': photo,
    });
    final snapshot = await LocalWorkspaceSnapshot(source).export();
    expect(snapshot, isNot(contains('source-files')));
    final restore = LocalWorkspaceSnapshot(target);
    await restore.restore(snapshot, storageRoot: targetFiles);
    await expectLater(
      restore.restore(snapshot, storageRoot: targetFiles),
      throwsStateError,
    );

    final db = await target.database;
    expect(
      await db.query('categories'),
      hasLength((await (await source.database).query('categories')).length),
    );
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    final entries = await EntryLocalDataSourceImpl(target).getEntries();
    expect(
      entries,
      hasLength((await (await source.database).query('entries')).length),
    );
    final featured = entries.singleWhere(
      (entry) => entry.privateContent.isNotEmpty,
    );
    expect(featured.privateContent, 'opaque-encrypted-payload');
    expect(featured.isPinned && featured.isFavorite, isTrue);
    expect(
      entryContentBlocks(featured.content).where((block) => block.structured),
      hasLength(3),
    );
    final attachments = {
      for (final item in featured.attachments) item.fileType: item,
    };
    expect(attachments.keys, unorderedEquals(['photo', 'audio', 'document']));
    expect(await File(attachments['photo']!.localPath).readAsBytes(), photo);
    expect(
      await File(attachments['audio']!.localPath).openRead(0, 4).first,
      'RIFF'.codeUnits,
    );
    expect(
      await File(attachments['document']!.localPath).readAsString(),
      startsWith('Entries review'),
    );

    final profile = ProfileStore(target, storageRoot: () async => targetFiles);
    addTearDown(profile.dispose);
    await profile.load();
    expect(profile.name, 'Alex Morgan');
    expect(profile.avatar, isNotEmpty);
    expect(await File(profile.originalPath!).readAsBytes(), photo);
    expect(p.isWithin(targetFiles.path, profile.originalPath!), isTrue);
    final restoredOriginal = File(profile.originalPath!);
    await profile.setAvatar(photo);
    await profile.load();
    expect(profile.avatar, photo);
    expect(await restoredOriginal.exists(), isFalse);
    await profile.setAvatar(null);
    await profile.load();
    expect(profile.avatar, isNull);
  });
}
