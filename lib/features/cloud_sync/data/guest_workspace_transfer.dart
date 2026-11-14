import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/database_helper.dart';
import '../../entry/data/datasources/entry_photo_storage.dart';
import 'local_workspace_snapshot.dart';
import 'workspace_merge.dart';

class GuestWorkspaceTransfer {
  const GuestWorkspaceTransfer(this._database, this._target);

  final DatabaseHelper _database;
  final DatabaseHelper _target;

  Future<DatabaseHelper> _guest() async {
    return DatabaseHelper.forUser(_database, await _database.guestUserId());
  }

  Future<bool> isAvailable() async {
    final db = await _database.database;
    if ((await db.query('guest_transfer', limit: 1)).isNotEmpty) return false;
    final guest = await _guest();
    return (await db.rawQuery(
      '''
      SELECT 1 FROM entries JOIN categories ON entries.category_id = categories.id
      WHERE categories.user_id = ? AND categories.is_deleted = 0
        AND entries.is_deleted = 0 AND entries.private_content = ''
      UNION ALL
      SELECT 1 FROM categories WHERE user_id = ? AND is_deleted = 0 AND is_default = 0
      AND NOT EXISTS (
        SELECT 1 FROM entries JOIN categories ON entries.category_id = categories.id
        WHERE categories.user_id = ? AND categories.is_deleted = 0
          AND entries.is_deleted = 0 AND entries.private_content != ''
      )
      LIMIT 1
    ''',
      [guest.userId, guest.userId, guest.userId],
    )).isNotEmpty;
  }

  Future<bool> prepare(String folderName) async {
    if (!await isAvailable()) return false;
    final guest = await _guest();
    final local = LocalWorkspaceSnapshot(_target);
    final guestContent = await LocalWorkspaceSnapshot(guest).export();
    final targetContent = await local.export();
    final guestData = jsonDecode(guestContent) as Map<String, dynamic>;
    final categories = (guestData['categories'] as List)
        .where((category) => category['is_deleted'] == 0)
        .map((category) => category['id'])
        .toSet();
    final entries = (guestData['entries'] as List)
        .cast<Map<String, dynamic>>()
        .where(
          (entry) =>
              entry['private_content'] == '' &&
              entry['is_deleted'] == 0 &&
              categories.contains(entry['category_id']),
        )
        .toList();
    final ids = entries.map((entry) => entry['id']).toSet();
    final categoryRows = (guestData['categories'] as List)
        .cast<Map<String, dynamic>>();
    final byId = {
      for (final category in categoryRows) category['id']: category,
    };
    final importCategories = <Object?>{};
    final hasPrivateEntries = (guestData['entries'] as List).any(
      (entry) => entry['private_content'] != '',
    );
    if (hasPrivateEntries) {
      for (final entry in entries) {
        var category = entry['category_id'];
        while (category != null && importCategories.add(category)) {
          category = byId[category]?['parent_id'];
        }
      }
    }
    final guestPublic = jsonEncode({
      ...guestData,
      if (hasPrivateEntries)
        'categories': categoryRows
            .where((category) => importCategories.contains(category['id']))
            .toList(),
      'entries': entries,
      'attachments': (guestData['attachments'] as List)
          .where((attachment) => ids.contains(attachment['entry_id']))
          .toList(),
    });
    final merged = mergeWorkspaceCopies(targetContent, [
      guestPublic,
    ], importFolder: folderName);
    if (merged == targetContent) return false;
    final fingerprint = await _fingerprint(guestContent);
    final destination = await _entryDigests(merged);
    final original = await _entryDigests(targetContent);
    final copiedIds = destination.keys
        .where((id) => !original.containsKey(id))
        .toList();
    final source = await _entryDigests(guestPublic);
    final copiedEntries = {
      for (final (index, id) in source.keys.indexed)
        id: {
          'source': source[id],
          'destinationId': copiedIds[index],
          'destination': destination[copiedIds[index]],
        },
    };
    final originalCategories = _categoryIds(targetContent).toSet();
    final copiedCategories = _categoryIds(merged)
        .where((id) => !originalCategories.contains(id))
        .toList();
    await local.restore(
      merged,
      storageRoot: await getApplicationSupportDirectory(),
      replaceExpected: targetContent,
      afterRestore: (txn) async {
        await txn.insert('guest_transfer', {
          'id': 1,
          'guest_id': guest.userId,
          'target_id': _target.userId,
          'guest_digest': jsonEncode({
            'snapshot': fingerprint,
            'entries': copiedEntries,
            'categories': copiedCategories,
          }),
        });
      },
    );
    return true;
  }

  Future<bool> get isPending async {
    final db = await _database.database;
    return (await db.query(
      'guest_transfer',
      columns: ['id'],
      where: 'target_id = ?',
      whereArgs: [_target.userId],
    )).isNotEmpty;
  }

  Future<void> finish(String confirmedTargetSnapshot) async {
    final db = await _database.database;
    final pending = (await db.query(
      'guest_transfer',
      where: 'target_id = ?',
      whereArgs: [_target.userId],
    )).singleOrNull;
    if (pending == null) return;
    final guestId = pending['guest_id'] as int;
    final guest = LocalWorkspaceSnapshot(
      DatabaseHelper.forUser(_database, guestId),
    );
    final snapshot = await guest.export();
    final manifest =
        jsonDecode(pending['guest_digest'] as String) as Map<String, dynamic>;
    final previous = manifest['entries'] as Map<String, dynamic>;
    final current = await _entryDigests(snapshot);
    final targetEntries = await _entryDigests(confirmedTargetSnapshot);
    final liveCategories = _categoryIds(confirmedTargetSnapshot).toSet();
    final unchanged = {
      for (final MapEntry(key: id, value: entry) in previous.entries)
        if (entry['source'] == current[id] &&
            entry['destination'] == targetEntries[entry['destinationId']])
          int.parse(id),
    };
    final removedMedia = await guest.removeTransferredEntries(
      snapshot,
      unchanged,
      removeCategories:
          unchanged.length == previous.length &&
          (manifest['categories'] as List).every(liveCategories.contains) &&
          await _fingerprint(snapshot) == manifest['snapshot'],
    );
    for (final file in removedMedia) {
      await const EntryPhotoStorage().removeAttachment(
        file['local_path'] as String,
        fileType: file['file_type'] as String,
      );
    }
  }

  Iterable<int> _categoryIds(String snapshot) =>
      (jsonDecode(snapshot)['categories'] as List)
          .where((category) => category['is_deleted'] == 0)
          .map((category) => category['id'] as int);

  Future<Map<String, String>> _entryDigests(String snapshot) async {
    final data = jsonDecode(snapshot) as Map<String, dynamic>;
    final attachments = <Object?, List<Object?>>{};
    for (final attachment in data['attachments'] as List) {
      (attachments[attachment['entry_id']] ??= []).add(attachment);
    }
    return {
      for (final entry in data['entries'] as List)
        '${entry['id']}': await _fingerprint(
          jsonEncode([entry, attachments[entry['id']]]),
        ),
    };
  }

  Future<String> _fingerprint(String snapshot) async =>
      base64Encode((await Sha256().hash(utf8.encode(snapshot))).bytes);
}
