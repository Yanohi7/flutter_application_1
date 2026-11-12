import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_application_1/core/database/database_helper.dart';
import 'package:flutter_application_1/features/cloud_sync/data/datasources/drive_workspace_store.dart';
import 'package:flutter_application_1/features/cloud_sync/data/local_workspace_snapshot.dart';
import 'package:flutter_application_1/features/cloud_sync/data/workspace_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'Two devices upload, restore updates, and keep both sides of a conflict',
    () async {
      final root = await Directory.systemTemp.createTemp('entries-drive-');
      addTearDown(() => root.delete(recursive: true));
      final first = DatabaseHelper.forTesting(p.join(root.path, 'first.db'));
      final second = DatabaseHelper.forTesting(p.join(root.path, 'second.db'));
      addTearDown(first.close);
      addTearDown(second.close);
      final id = await first.ensureDefaultCategory();
      final db = await first.database;
      await db.insert('entries', {
        'category_id': id,
        'title': 'Initial entry',
        'content': 'Text before sync',
        'created_at': '2026-11-11T12:00:00Z',
        'updated_at': '2026-11-11T12:00:00Z',
      });

      final drive = _FakeDrive();
      final store = DriveWorkspaceStore(
        () async => {'Authorization': 'Bearer test-token'},
        testWorkspace: true,
        client: MockClient(drive.request),
      );
      addTearDown(store.close);
      final firstSync = WorkspaceSync(
        LocalWorkspaceSnapshot(first),
        store,
        () async => root,
      );
      final secondSync = WorkspaceSync(
        LocalWorkspaceSnapshot(second),
        store,
        () async => root,
      );
      Future<void> apply(Future<void> Function() operation) => operation();

      final upload = await firstSync.sync(applyDownload: apply);
      expect(upload.result, WorkspaceSyncResult.uploaded);
      final restore = await secondSync.sync(applyDownload: apply);
      expect(restore.result, WorkspaceSyncResult.downloaded);
      expect(restore.digest, upload.digest);
      final secondDb = await second.database;
      expect(
        (await secondDb.query('entries')).single['content'],
        'Text before sync',
      );
      expect(
        (await secondSync.sync(
          previousDigest: restore.digest,
          applyDownload: apply,
        )).result,
        WorkspaceSyncResult.current,
      );

      await db.update('entries', {'content': 'Updated on first device'});
      final latest = await firstSync.sync(
        previousDigest: upload.digest,
        applyDownload: apply,
      );
      final updated = await secondSync.sync(
        previousDigest: restore.digest,
        applyDownload: apply,
      );
      expect(updated.digest, latest.digest);
      expect(
        (await secondDb.query('entries')).single['content'],
        'Updated on first device',
      );
      expect(await secondDb.rawQuery('PRAGMA foreign_key_check'), isEmpty);

      await secondDb.update('entries', {'content': 'Second device edit'});
      await db.update('entries', {'content': 'First device edit'});
      final document = File(p.join(root.path, 'drive-copy.txt'));
      final documentText = 'Attachment from the Drive copy\n' * 12000;
      await document.writeAsString(documentText);
      await db.insert('media_attachments', {
        'entry_id': (await db.query('entries')).single['id'],
        'file_type': 'document',
        'file_name': 'drive-copy.txt',
        'local_path': document.path,
        'created_at': '2026-11-11T12:00:00Z',
      });
      final diverged = await firstSync.sync(
        previousDigest: latest.digest,
        applyDownload: apply,
      );
      WorkspaceConflict? conflict;
      await expectLater(
        secondSync.sync(previousDigest: updated.digest, applyDownload: apply),
        throwsA(
          isA<WorkspaceConflict>().having(
            (error) {
              conflict = error;
              return error.heads.length;
            },
            'Drive versions',
            1,
          ),
        ),
      );
      expect(
        (await secondDb.query('entries')).single['content'],
        'Second device edit',
      );
      expect(drive.revisions, hasLength(3));

      final mergedDigest = await secondSync.keepBoth(conflict!);
      expect(drive.revisions, hasLength(4));
      final merged = await secondDb.query('entries', orderBy: 'id');
      expect(merged.map((row) => row['content']), [
        'Second device edit',
        'First device edit',
      ]);
      final copiedFile = (await secondDb.query('media_attachments')).single;
      expect(copiedFile['entry_id'], merged.last['id']);
      expect(
        await File(copiedFile['local_path'] as String).readAsString(),
        documentText,
      );
      expect(await secondDb.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      final synced = await secondSync.sync(
        previousDigest: mergedDigest,
        applyDownload: apply,
      );
      expect(synced.result, WorkspaceSyncResult.current);
      expect(drive.revisions, hasLength(4));
      final onFirst = await firstSync.sync(
        previousDigest: diverged.digest,
        applyDownload: apply,
      );
      expect(onFirst.digest, mergedDigest);
      expect(await db.query('entries', orderBy: 'id'), merged);
    },
  );
}

class _FakeDrive {
  final revisions = <Map<String, dynamic>>[];
  final bodies = <String, Uint8List>{};
  Map<String, dynamic>? _pending;

  Future<http.Response> request(http.Request request) async {
    final uri = request.url;
    expect(uri.host, 'www.googleapis.com');
    if (request.method == 'GET' && uri.path == '/drive/v3/files') {
      expect(uri.queryParameters['spaces'], 'appDataFolder');
      expect(uri.queryParameters['q'], contains('entries_test_sync_v1.json'));
      expect(request.headers['Authorization'], 'Bearer test-token');
      return http.Response(jsonEncode({'files': revisions}), 200);
    }
    if (request.method == 'POST') {
      expect(uri.queryParameters['uploadType'], 'resumable');
      _pending = jsonDecode(request.body) as Map<String, dynamic>;
      expect(_pending!['parents'], ['appDataFolder']);
      return http.Response(
        '',
        200,
        headers: {
          'location':
              'https://www.googleapis.com/upload/drive/v3/files?upload_id=test',
        },
      );
    }
    if (request.method == 'PUT') {
      final id = '${revisions.length + 1}';
      revisions.add({'id': id, 'appProperties': _pending!['appProperties']});
      bodies[id] = request.bodyBytes;
      _pending = null;
      return http.Response('', 200);
    }
    expect(uri.queryParameters['alt'], 'media');
    return http.Response.bytes(bodies[uri.pathSegments.last]!, 200);
  }
}
