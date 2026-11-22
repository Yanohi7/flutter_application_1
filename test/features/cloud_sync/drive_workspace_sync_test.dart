import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_application_1/core/database/database_helper.dart';
import 'package:flutter_application_1/features/cloud_sync/data/datasources/drive_workspace_store.dart';
import 'package:flutter_application_1/features/cloud_sync/data/local_workspace_snapshot.dart';
import 'package:flutter_application_1/features/cloud_sync/data/workspace_sync.dart';
import 'package:flutter_application_1/features/entry/data/datasources/entry_local_datasource.dart';
import 'package:flutter_application_1/features/entry/data/repositories/entry_repository_impl.dart';
import 'package:flutter_application_1/features/entry/domain/usecases/create_entry.dart';
import 'package:flutter_application_1/features/category/data/datasources/category_local_datasource.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('Personal workspace', () {
    late Directory root;
    late _FakeDrive drive;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('entries-personal-drive-');
      addTearDown(() => root.delete(recursive: true));
      drive = _FakeDrive();
    });

    Future<
      ({
        EntryRepositoryImpl entries,
        CategoryLocalDataSource categories,
        WorkspaceSync sync,
      })
    >
    openDevice(String name, {bool testWorkspace = false}) async {
      final files = await Directory(p.join(root.path, name)).create();
      final database = DatabaseHelper.forTesting(
        p.join(files.path, 'entries.db'),
      );
      addTearDown(database.close);
      final account = await database.getOrCreateGoogleAccount(
        googleAccountId: 'same-google-account',
        email: 'entries@example.test',
      );
      final workspace = DatabaseHelper.forUser(database, account.id);
      final store = DriveWorkspaceStore(
        () async => {'Authorization': 'Bearer test-token'},
        testWorkspace: testWorkspace,
        client: MockClient(drive.request),
      );
      addTearDown(store.close);
      return (
        entries: EntryRepositoryImpl(EntryLocalDataSourceImpl(workspace)),
        categories: CategoryLocalDataSource(workspace),
        sync: WorkspaceSync(
          LocalWorkspaceSnapshot(workspace),
          store,
          () async => files,
        ),
      );
    }

    Future<void> apply(Future<void> Function() operation) => operation();

    test(
      'A new personal note syncs to an already connected second device',
      () async {
        final phone = await openDevice('phone');
        final emulator = await openDevice('emulator');
        await CreateEntry(phone.entries)(
          title: 'Existing note',
          content: 'Before',
        );
        final firstUpload = await phone.sync.sync(applyDownload: apply);
        expect(firstUpload.result, WorkspaceSyncResult.uploaded);
        final baseline = await emulator.sync.sync(applyDownload: apply);
        expect(baseline.result, WorkspaceSyncResult.downloaded);
        expect(baseline.digest, firstUpload.digest);
        expect(
          (await emulator.entries.getEntries()).single.title,
          'Existing note',
        );

        await CreateEntry(phone.entries)(
          title: 'From my phone',
          content: 'New text',
        );
        final upload = await phone.sync.sync(
          previousDigest: firstUpload.digest,
          applyDownload: apply,
        );
        expect(upload.result, WorkspaceSyncResult.uploaded);
        final download = await emulator.sync.sync(
          previousDigest: baseline.digest,
          localKnownUnchanged: true,
          applyDownload: apply,
        );
        expect(download.result, WorkspaceSyncResult.downloaded);
        expect(download.digest, upload.digest);
        final entries = await emulator.entries.getEntries();
        expect(
          entries.map((entry) => entry.title),
          unorderedEquals(['Existing note', 'From my phone']),
        );
        expect(
          entries
              .singleWhere((entry) => entry.title == 'From my phone')
              .content,
          'New text',
        );
        expect(
          drive.revisions.map((revision) => revision['name']),
          everyElement('entries_sync_v1.json'),
        );
      },
    );

    test(
      'Independently created personal notes stay in their shared category',
      () async {
        final phone = await openDevice('phone');
        final emulator = await openDevice('emulator');
        await CreateEntry(phone.entries)(
          title: 'Shared note',
          content: 'Baseline',
        );
        final initial = await phone.sync.sync(applyDownload: apply);
        final baseline = await emulator.sync.sync(applyDownload: apply);
        expect(baseline.digest, initial.digest);

        await CreateEntry(phone.entries)(
          title: 'From phone',
          content: 'Phone text',
        );
        await CreateEntry(emulator.entries)(
          title: 'From emulator',
          content: 'Emulator text',
        );
        final upload = await phone.sync.sync(
          previousDigest: initial.digest,
          applyDownload: apply,
        );
        expect(upload.result, WorkspaceSyncResult.uploaded);
        final merged = await emulator.sync.sync(
          previousDigest: baseline.digest,
          applyDownload: apply,
        );
        expect(merged.result, WorkspaceSyncResult.merged);
        final download = await phone.sync.sync(
          previousDigest: upload.digest,
          applyDownload: apply,
        );
        expect(download.result, WorkspaceSyncResult.downloaded);
        expect(download.digest, merged.digest);

        for (final device in [phone, emulator]) {
          final entries = await device.entries.getEntries();
          expect(
            entries.map((entry) => (entry.title, entry.content)),
            unorderedEquals([
              ('Shared note', 'Baseline'),
              ('From phone', 'Phone text'),
              ('From emulator', 'Emulator text'),
            ]),
          );
          expect(
            entries.map((entry) => entry.categoryName),
            everyElement('General'),
          );
          expect(
            (await device.categories.getCategories()).map(
              (category) => category.name,
            ),
            ['General'],
          );
        }
        expect(drive.revisions, hasLength(3));
      },
    );

    test('Personal and test workspaces use separate Drive backups', () async {
      final demo = await openDevice('demo', testWorkspace: true);
      final personal = await openDevice('personal');
      final otherDevice = await openDevice('other-personal');

      await CreateEntry(demo.entries)(title: 'Demo only', content: 'Demo');
      expect(
        (await demo.sync.sync(applyDownload: apply)).result,
        WorkspaceSyncResult.uploaded,
      );
      expect(
        (await personal.sync.sync(applyDownload: apply)).result,
        WorkspaceSyncResult.empty,
      );
      expect(await personal.entries.getEntries(), isEmpty);

      await CreateEntry(personal.entries)(
        title: 'Personal only',
        content: 'Personal',
      );
      expect(
        (await personal.sync.sync(applyDownload: apply)).result,
        WorkspaceSyncResult.uploaded,
      );
      expect(
        (await otherDevice.sync.sync(applyDownload: apply)).result,
        WorkspaceSyncResult.downloaded,
      );
      expect(
        (await otherDevice.entries.getEntries()).single.title,
        'Personal only',
      );
      expect(
        drive.revisions.map((revision) => revision['name']),
        unorderedEquals(['entries_test_sync_v1.json', 'entries_sync_v1.json']),
      );
    });
  });

  test(
    'IT-03 Two devices automatically keep both edits without repeat copies',
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
      expect(drive.revisions, hasLength(3));
      final resolution = await secondSync.sync(
        previousDigest: updated.digest,
        applyDownload: apply,
      );
      expect(resolution.result, WorkspaceSyncResult.merged);
      final mergedDigest = resolution.digest;
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
      // SQLite assigns local IDs on restore; the sync IDs must match.
      const syncedEntries = '''
        SELECT e.sync_id, c.sync_id AS category_sync_id, e.title, e.content,
               e.private_content, e.created_at, e.updated_at, e.is_pinned,
               e.is_favorite, e.is_deleted, e.deleted_at
        FROM entries e
        JOIN categories c ON c.id = e.category_id
        ORDER BY e.sync_id
      ''';
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect(
        await db.rawQuery(syncedEntries),
        await secondDb.rawQuery(syncedEntries),
      );
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
      final query = uri.queryParameters['q'];
      expect(
        query,
        anyOf(
          "name = 'entries_test_sync_v1.json'",
          "name = 'entries_sync_v1.json'",
        ),
      );
      expect(request.headers['Authorization'], 'Bearer test-token');
      final matches = revisions.where(
        (revision) => query == "name = '${revision['name']}'",
      );
      return http.Response(jsonEncode({'files': matches.toList()}), 200);
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
      revisions.add({
        'id': id,
        'name': _pending!['name'],
        'appProperties': _pending!['appProperties'],
      });
      bodies[id] = request.bodyBytes;
      _pending = null;
      return http.Response('', 200);
    }
    expect(uri.queryParameters['alt'], 'media');
    return http.Response.bytes(bodies[uri.pathSegments.last]!, 200);
  }
}
