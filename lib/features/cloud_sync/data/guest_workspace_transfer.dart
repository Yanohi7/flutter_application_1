import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/security/private_content_store.dart';
import '../../entry/data/datasources/entry_photo_storage.dart';
import 'datasources/drive_workspace_store.dart';
import 'local_workspace_snapshot.dart';
import 'workspace_merge.dart';
import 'workspace_sync.dart' show PrivateMergeCanceled;

typedef GuestPrivatePassword =
    Future<({String? password, bool useDevice})?> Function({
      required bool guest,
      required bool creating,
      required bool allowDevice,
    });

const guestTransferFolderName = 'Entries from this device';

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
        AND entries.is_deleted = 0
      UNION ALL
      SELECT 1 FROM categories WHERE user_id = ? AND is_deleted = 0 AND is_default = 0
      LIMIT 1
    ''',
      [guest.userId, guest.userId],
    )).isNotEmpty;
  }

  Future<bool> get hasPrivateEntries async {
    final guest = await _guest();
    final db = await _database.database;
    return (await db.rawQuery(
      '''
      SELECT 1 FROM entries JOIN categories ON entries.category_id = categories.id
      WHERE categories.user_id = ? AND categories.is_deleted = 0
        AND entries.is_deleted = 0 AND entries.private_content != ''
      LIMIT 1
      ''',
      [guest.userId],
    )).isNotEmpty;
  }

  Future<bool> prepare({
    required String? guestNamespace,
    required GuestPrivatePassword requestPassword,
    required String unlockPrompt,
    required bool skipPrivate,
  }) async {
    if (!await isAvailable()) return false;
    final guest = await _guest();
    final local = LocalWorkspaceSnapshot(_target);
    final guestSnapshot = LocalWorkspaceSnapshot(guest);
    final guestContent = await guestSnapshot.export();
    final targetContent = await local.export();
    final guestData = jsonDecode(guestContent) as Map<String, dynamic>;
    final categoryRows = (guestData['categories'] as List)
        .cast<Map<String, dynamic>>();
    final categories = {
      for (final category in categoryRows)
        if (category['is_deleted'] == 0) category['id']: category,
    };
    final allGuestEntries = (guestData['entries'] as List)
        .cast<Map<String, dynamic>>();
    final entries = allGuestEntries
        .where(
          (entry) =>
              entry['is_deleted'] == 0 &&
              categories.containsKey(entry['category_id']) &&
              (!skipPrivate || entry['private_content'] == ''),
        )
        .map(Map<String, dynamic>.of)
        .toList();
    final ids = entries.map((entry) => entry['id']).toSet();
    final guestCategories = <Object?>{};
    if (skipPrivate) {
      for (final entry in entries) {
        var id = entry['category_id'];
        while (id != null && guestCategories.add(id)) {
          id = categories[id]?['parent_id'];
        }
      }
      if (entries.isEmpty) return false;
    }
    String? envelopeToImport;
    String? rotatedGuestEnvelope;
    var confirmedGuest = guestContent;
    if (entries.any((entry) => entry['private_content'] != '')) {
      if (PrivateContentStore.supportsBiometrics &&
          !await PrivateContentStore.hasScreenLock()) {
        throw const DriveSyncException(
          'Set up a screen lock in your phone settings.',
        );
      }
      final sourceEnvelope =
          await PrivateContentStore.readPasswordEnvelopeForWorkspace(
            guestNamespace,
            userId: guest.userId,
          );
      if (sourceEnvelope == null) {
        throw const DriveSyncException(
          'Set a private password in Guest before moving private entries.',
        );
      }
      final targetEnvelope =
          await PrivateContentStore.readSyncPasswordEnvelope();
      final source = await _unlock(
        sourceEnvelope,
        requestPassword,
        namespace: guestNamespace,
        userId: guest.userId,
        guest: true,
        unlockPrompt: unlockPrompt,
      );
      try {
        final SecretKey targetKey;
        if (targetEnvelope == null) {
          final password = await _newPassword(requestPassword, guest: false);
          targetKey = await PrivateContentStore.cipher.newSecretKey();
          try {
            envelopeToImport = await PrivateContentStore.createPasswordEnvelope(
              targetKey,
              password,
            );
            await PrivateContentStore.prepareDeviceRecovery(targetKey);
          } catch (_) {
            targetKey.destroy();
            rethrow;
          }
        } else {
          targetKey = (await _unlock(
            targetEnvelope,
            requestPassword,
            guest: false,
            unlockPrompt: unlockPrompt,
          )).key;
        }
        try {
          if (await PrivateContentStore.keysMatch(source.key, targetKey)) {
            // Rotate the legacy Guest key and its ciphertext in one database commit.
            final password =
                source.password ??
                await _newPassword(requestPassword, guest: true);
            final replacement = await PrivateContentStore.cipher.newSecretKey();
            try {
              rotatedGuestEnvelope =
                  await PrivateContentStore.createPasswordEnvelope(
                    replacement,
                    password,
                  );
              await PrivateContentStore.prepareWorkspaceDeviceRecovery(
                replacement,
                guestNamespace,
              );
              await reencryptWorkspacePrivateEntries(
                allGuestEntries,
                source.key,
                replacement,
              );
              confirmedGuest = jsonEncode(guestData);
            } finally {
              replacement.destroy();
            }
          }
          await reencryptWorkspacePrivateEntries(
            entries,
            source.key,
            targetKey,
          );
        } finally {
          targetKey.destroy();
        }
      } finally {
        source.key.destroy();
      }
    }
    final source = await _entryDigests(confirmedGuest);
    final guestImport = jsonEncode({
      ...guestData,
      if (skipPrivate)
        'categories': categoryRows
            .where((row) => guestCategories.contains(row['id']))
            .toList(),
      'entries': entries,
      'attachments': (guestData['attachments'] as List)
          .where((attachment) => ids.contains(attachment['entry_id']))
          .toList(),
    });
    final merged = mergeWorkspaceCopies(targetContent, [
      guestImport,
    ], importFolder: guestTransferFolderName);
    if (merged == targetContent) return false;
    final fingerprint = await _fingerprint(confirmedGuest);
    final destination = await _entryDigests(merged);
    final original = await _entryDigests(targetContent);
    final copiedIds = destination.keys
        .where((id) => !original.containsKey(id))
        .toList();
    final copiedEntries = {
      for (final (index, entry) in entries.indexed)
        '${entry['id']}': {
          'source': source['${entry['id']}'],
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
        if (rotatedGuestEnvelope case final envelope?) {
          await guestSnapshot.rewritePrivateEntries(
            txn,
            guestContent,
            allGuestEntries.where(
              (row) => row['is_deleted'] == 0 && row['private_content'] != '',
            ),
          );
          await PrivateContentStore.writeWorkspaceEnvelope(
            txn,
            guest.userId!,
            envelope,
          );
        }
        await txn.insert('guest_transfer', {
          'id': 1,
          'guest_id': guest.userId,
          'target_id': _target.userId,
          'guest_digest': jsonEncode({
            'snapshot': fingerprint,
            'entries': copiedEntries,
            'categories': copiedCategories,
            'partial': skipPrivate,
          }),
        });
        if (envelopeToImport case final envelope?) {
          await PrivateContentStore.writeWorkspaceEnvelope(
            txn,
            _target.userId!,
            envelope,
          );
        }
      },
    );
    return true;
  }

  Future<String> _newPassword(
    GuestPrivatePassword requestPassword, {
    required bool guest,
  }) async {
    final response = await requestPassword(
      guest: guest,
      creating: true,
      allowDevice: false,
    );
    if (response?.password case final password?) return password;
    throw const PrivateMergeCanceled();
  }

  Future<({SecretKeyData key, String? password})> _unlock(
    String envelope,
    GuestPrivatePassword requestPassword, {
    required bool guest,
    required String unlockPrompt,
    String? namespace,
    int? userId,
  }) async {
    final response = await requestPassword(
      guest: guest,
      creating: false,
      allowDevice: await PrivateContentStore.hasDeviceRecovery(
        namespace: namespace,
        userId: userId,
      ),
    );
    if (response == null) throw const PrivateMergeCanceled();
    if (response.useDevice) {
      try {
        final key = await PrivateContentStore.unlockWithDeviceRecovery(
          prompt: unlockPrompt,
          namespace: namespace,
          userId: userId,
        );
        if (key == null) throw const PrivateMergeCanceled();
        return (key: key, password: null);
      } on FormatException {
        throw const DriveSyncException(
          'Could not verify your screen lock. Try again.',
        );
      } on PlatformException {
        throw const DriveSyncException(
          'Could not verify your screen lock. Try again.',
        );
      }
    }
    final password = response.password!;
    try {
      return (
        key: await PrivateContentStore.unlockPasswordEnvelope(
          envelope,
          password,
        ),
        password: password,
      );
    } on FormatException {
      throw const DriveSyncException('Incorrect private password.');
    }
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
          manifest['partial'] != true &&
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
