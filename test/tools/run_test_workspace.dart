import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/database/database_helper.dart';
import 'package:flutter_application_1/core/security/private_content_store.dart';
import 'package:flutter_application_1/main.dart' as app;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../support/populate_test_database.dart';

const _workspace = 'test_workspace_bilingual';

Future<void> main() => app.startEntries(
  repeatOnboarding: true,
  testWorkspaceNamespace: _workspace,
  prepareWorkspace: () async {
    final root = Directory(
      p.join((await getApplicationSupportDirectory()).path, _workspace),
    );
    await root.create(recursive: true);
    final helper = DatabaseHelper.forTesting(
      p.join(root.path, 'entries_test.db'),
    );
    final db = await helper.database;
    if ((await db.query('users', columns: ['id'], limit: 1)).isEmpty) {
      final photo = await rootBundle.load('assets/images/spiderman-bg.jpg');
      final hasPassword = await PrivateContentStore.hasPassword();
      final key = await PrivateContentStore.unlockWithPassword(
        'entries-test',
        isExisting: hasPassword,
      );
      final privateContent = await PrivateContentStore.encrypt(
        'This is a synthetic private note for testing the unlock flow.',
        key,
      );
      key.destroy();
      await populateTestDatabase(
        db,
        mediaDirectory: Directory(p.join(root.path, 'media')),
        photo: photo.buffer.asUint8List(
          photo.offsetInBytes,
          photo.lengthInBytes,
        ),
        privateContent: privateContent,
      );
    } else {
      final profiles = await db.query(
        'profiles',
        columns: ['id', 'avatar_image', 'avatar_original_path'],
      );
      for (final profile in profiles) {
        final avatar = profile['avatar_image'];
        if (profile['avatar_original_path'] != null || avatar is! Uint8List)
          continue;
        final hash = await Sha256().hash(avatar);
        if (hash.bytes
                .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
                .join() ==
            '8e171e1b56661e34c503df6e4974872fec0be7b5079a143530f74082c46c233e') {
          await db.update(
            'profiles',
            {'avatar_image': null},
            where: 'id = ?',
            whereArgs: [profile['id']],
          );
        }
      }
    }
    return helper;
  },
);
