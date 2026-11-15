import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../entry/data/datasources/entry_photo_storage.dart';
import '../../profile/data/profile_store.dart';

/// Transfers a workspace to a fresh device using portable content and media bytes.
class LocalWorkspaceSnapshot {
  const LocalWorkspaceSnapshot(this._helper);

  final DatabaseHelper _helper;

  static const _categoryColumns = [
    'id',
    'name',
    'parent_id',
    'is_system',
    'is_default',
    'sort_order',
    'is_deleted',
    'deleted_at',
    'created_at',
    'updated_at',
  ];
  static const _entryColumns = [
    'id',
    'category_id',
    'title',
    'content',
    'private_content',
    'created_at',
    'updated_at',
    'is_pinned',
    'is_favorite',
    'is_deleted',
    'deleted_at',
  ];
  static const _attachmentColumns = [
    'id',
    'entry_id',
    'file_type',
    'file_name',
    'display_name',
    'mime_type',
    'created_at',
  ];
  static const _attachmentDeletionColumns = [
    'id',
    'entry_id',
    'file_type',
    'created_at',
    'deleted_at',
  ];

  Future<String> export() async => (await exportForSync()).content;

  Future<({String content, bool isEmpty, bool hasPrivate})>
  exportForSync() async {
    await _helper.ensureDefaultCategory();
    final db = await _helper.database;
    return db.transaction(_snapshot);
  }

  Future<({String content, bool isEmpty, bool hasPrivate})> _snapshot(
    Transaction txn,
  ) async {
    final userId = await _userId(txn);
    final profile = await txn.query(
      'profiles',
      columns: [
        'display_name',
        'avatar_image',
        'avatar_original_path',
        'created_at',
      ],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    final profileRow = profile.singleOrNull;
    final categories = await txn.query(
      'categories',
      columns: [..._categoryColumns, 'sync_id'],
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id',
    );
    final entries = await txn.rawQuery(
      '''
        SELECT ${_entryColumns.map((column) => 'entries.$column').join(', ')}
        , entries.sync_id FROM entries JOIN categories
          ON entries.category_id = categories.id WHERE categories.user_id = ?
        ORDER BY entries.id
      ''',
      [userId],
    );
    final attachments = await txn.rawQuery(
      '''
        SELECT media_attachments.id, entry_id, file_type, file_name,
          display_name, local_path, mime_type, media_attachments.created_at,
          media_attachments.sync_id, media_attachments.is_deleted, media_attachments.deleted_at
        FROM media_attachments JOIN entries
          ON media_attachments.entry_id = entries.id
        JOIN categories ON entries.category_id = categories.id
        WHERE categories.user_id = ?
          AND entries.is_deleted = 0 AND categories.is_deleted = 0
        ORDER BY media_attachments.id
      ''',
      [userId],
    );
    final categoryIds = await _portableIds(txn, 'categories', categories);
    final entryIds = await _portableIds(txn, 'entries', entries);
    final attachmentIds = await _portableIds(
      txn,
      'media_attachments',
      attachments,
    );
    final input = (
      profile: profileRow,
      categories: _portableRows(
        categories,
        _categoryColumns,
        categoryIds,
        'parent_id',
        categoryIds,
      ),
      entries: _portableRows(
        entries,
        _entryColumns,
        entryIds,
        'category_id',
        categoryIds,
      ),
      attachments: _portableRows(
        attachments,
        [..._attachmentColumns, 'local_path', 'is_deleted', 'deleted_at'],
        attachmentIds,
        'entry_id',
        entryIds,
      ),
    );
    final hasMedia =
        attachments.any((row) => row['is_deleted'] == 0) ||
        profileRow?['avatar_image'] != null ||
        profileRow?['avatar_original_path'] != null;
    final content =
        hasMedia ||
            entries.length >= 128 ||
            entries.any((row) => (row['content'] as String).length >= 65536)
        ? await compute(_encode, input)
        : await _encode(input);
    return (
      content: content,
      hasPrivate: entries.any(
        (row) => row['is_deleted'] == 0 && row['private_content'] != '',
      ),
      isEmpty:
          entries.isEmpty &&
          categories.length == 1 &&
          categories.single['is_default'] == 1 &&
          const ['General', 'Default'].contains(categories.single['name']) &&
          profileRow?['avatar_image'] == null &&
          (profileRow?['display_name'] ?? 'Guest') == 'Guest',
    );
  }

  Future<Map<int, int>> _portableIds(
    Transaction txn,
    String table,
    List<Map<String, Object?>> rows,
  ) async {
    final ids = <int, int>{
      for (final row in rows)
        if (row['sync_id'] case final int id) row['id'] as int: id,
    };
    final taken = ids.values.toSet();
    var next = taken.fold(0, (max, id) => id > max ? id : max) + 1;
    final batch = txn.batch();
    var updated = false;
    for (final row in rows) {
      final local = row['id'] as int;
      if (ids.containsKey(local)) continue;
      var portable = local;
      if (!taken.add(portable)) {
        while (!taken.add(next)) {
          next++;
        }
        portable = next++;
      }
      ids[local] = portable;
      batch.update(
        table,
        {'sync_id': portable},
        where: 'id = ?',
        whereArgs: [local],
      );
      updated = true;
    }
    if (updated) await batch.commit(noResult: true);
    return ids;
  }

  List<Map<String, Object?>> _portableRows(
    List<Map<String, Object?>> rows,
    List<String> columns,
    Map<int, int> ids,
    String reference,
    Map<int, int> references,
  ) => [
    for (final row in rows)
      {
        for (final column in columns)
          column: switch (column) {
            'id' => ids[row['id']],
            _ when column == reference => references[row[reference]],
            _ => row[column],
          },
      },
  ]..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));

  static Future<String> _encode(
    ({
      Map<String, Object?>? profile,
      List<Map<String, Object?>> categories,
      List<Map<String, Object?>> entries,
      List<Map<String, Object?>> attachments,
    })
    input,
  ) async {
    final profile = input.profile;
    final avatar = profile?['avatar_image'] as List<int>?;
    final originalPath = profile?['avatar_original_path'] as String?;
    final original = originalPath == null ? null : File(originalPath);
    return jsonEncode({
      'version': 1,
      'profile': {
        'display_name': profile?['display_name'] ?? 'Guest',
        'created_at': profile?['created_at'],
        'avatar': avatar == null ? null : base64Encode(avatar),
        'original': original == null || !await original.exists()
            ? null
            : base64Encode(await original.readAsBytes()),
      },
      'categories': input.categories,
      'entries': [
        for (final entry in input.entries)
          entry['is_deleted'] == 0
              ? entry
              : {
                  ...entry,
                  'title': '',
                  'content': '',
                  'private_content': '',
                  'is_pinned': 0,
                  'is_favorite': 0,
                },
      ],
      'attachments': [
        for (final attachment in input.attachments.where(
          (row) => row['is_deleted'] == 0,
        ))
          {
            for (final column in _attachmentColumns) column: attachment[column],
            'bytes': base64Encode(
              await File(attachment['local_path'] as String).readAsBytes(),
            ),
          },
      ],
      if (input.attachments.any((row) => row['is_deleted'] == 1))
        'attachmentDeletions': [
          for (final attachment in input.attachments.where(
            (row) => row['is_deleted'] == 1,
          ))
            {
              for (final column in _attachmentDeletionColumns)
                column: attachment[column],
            },
        ],
    });
  }

  Future<void> restore(
    String snapshot, {
    required Directory storageRoot,
    String? replaceExpected,
    Future<void> Function(Transaction)? afterRestore,
  }) async {
    final data = snapshot.length >= 256 * 1024
        ? await compute(_decode, snapshot)
        : _decode(snapshot);
    if (data is! Map<String, dynamic> || data['version'] != 1) {
      throw const FormatException('Unsupported Entries workspace format.');
    }
    final profile = data['profile'] as Map<String, dynamic>;
    final avatar = profile['avatar'] as String?;
    final original = profile['original'] as String?;
    final categories = _rows(data, 'categories', _categoryColumns);
    final entries = _rows(data, 'entries', _entryColumns);
    final attachments = _rows(data, 'attachments', [
      ..._attachmentColumns,
      'bytes',
    ]);
    final attachmentDeletions = data.containsKey('attachmentDeletions')
        ? _rows(data, 'attachmentDeletions', _attachmentDeletionColumns)
        : const <Map<String, Object?>>[];
    if (categories
            .where((row) => row['is_default'] == 1 && row['is_deleted'] == 0)
            .length !=
        1) {
      throw const FormatException(
        'The workspace must have one default category.',
      );
    }
    await _helper.ensureDefaultCategory();
    final db = await _helper.database;
    final staged = <Directory>[];
    List<Map<String, Object?>> oldAttachments = const [];
    String? oldAvatar;
    try {
      await db.transaction((txn) async {
        final userId = await _userId(txn);
        final hasContent = await txn.rawQuery(
          '''
          SELECT EXISTS(
            SELECT 1 FROM entries JOIN categories ON entries.category_id = categories.id
            WHERE categories.user_id = ?
          ) OR EXISTS(
            SELECT 1 FROM categories WHERE user_id = ? AND is_default = 0
          ) OR EXISTS(
            SELECT 1 FROM profiles WHERE user_id = ? AND avatar_image IS NOT NULL
          ) AS has_content
        ''',
          [userId, userId, userId],
        );
        if (replaceExpected != null) {
          if ((await _snapshot(txn)).content != replaceExpected) {
            throw StateError('Entries changed during sync. Try again.');
          }
          oldAttachments = await txn.rawQuery(
            '''
            SELECT media_attachments.local_path, media_attachments.file_type
            FROM media_attachments
            JOIN entries ON media_attachments.entry_id = entries.id
            JOIN categories ON entries.category_id = categories.id
            WHERE categories.user_id = ? AND media_attachments.local_path != ''
          ''',
            [userId],
          );
          final profiles = await txn.query(
            'profiles',
            columns: ['avatar_original_path'],
            where: 'user_id = ?',
            whereArgs: [userId],
            limit: 1,
          );
          oldAvatar = profiles.singleOrNull?['avatar_original_path'] as String?;
          await txn.rawDelete(
            '''
            DELETE FROM media_attachments WHERE entry_id IN (
              SELECT entries.id FROM entries JOIN categories ON entries.category_id = categories.id
              WHERE categories.user_id = ?
            )
          ''',
            [userId],
          );
          await txn.rawDelete(
            '''
            DELETE FROM entries WHERE category_id IN (
              SELECT id FROM categories WHERE user_id = ?
            )
          ''',
            [userId],
          );
        } else if (hasContent.single['has_content'] == 1) {
          throw StateError('This workspace already contains local data.');
        }
        await txn.delete(
          'categories',
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        await txn.execute('PRAGMA defer_foreign_keys = ON;');
        final sequence = await txn.query(
          'sqlite_sequence',
          columns: ['seq'],
          where: 'name = ?',
          whereArgs: ['categories'],
        );
        var nextCategory = (sequence.singleOrNull?['seq'] as int? ?? 0) + 1;
        final categoryIds = {
          for (final row in categories) row['id']: nextCategory++,
        };
        for (final row in categories) {
          await txn.insert('categories', {
            ...row,
            'id': categoryIds[row['id']],
            'sync_id': row['id'],
            'parent_id': row['parent_id'] == null
                ? null
                : categoryIds[row['parent_id']]!,
            'user_id': userId,
          });
        }
        final entryIds = <Object?, int>{};
        for (final row in entries) {
          final portable = row.remove('id');
          entryIds[portable] = await txn.insert('entries', {
            ...row,
            'sync_id': portable,
            'category_id': categoryIds[row['category_id']]!,
          });
        }
        for (final row in attachments) {
          final type = row['file_type'];
          if (!const ['photo', 'audio', 'document', 'video'].contains(type)) {
            throw const FormatException('Unsupported attachment type.');
          }
          final bytes = await _decodeMedia(row.remove('bytes') as String);
          final extension = p
              .extension(row['file_name'] as String)
              .toLowerCase();
          final safeExtension =
              RegExp(r'^\.[a-z0-9]{1,10}$').hasMatch(extension)
              ? extension
              : '';
          final root = Directory(p.join(storageRoot.path, 'entry_${type}s'));
          await root.create(recursive: true);
          final folder = await root.createTemp('${type}_');
          staged.add(folder);
          final file = File(p.join(folder.path, 'attachment$safeExtension'));
          await file.writeAsBytes(bytes, flush: true);
          final portable = row.remove('id');
          await txn.insert('media_attachments', {
            ...row,
            'sync_id': portable,
            'entry_id': entryIds[row['entry_id']]!,
            'local_path': file.path,
            'file_size': bytes.length,
          });
        }
        for (final row in attachmentDeletions) {
          final portable = row.remove('id');
          await txn.insert('media_attachments', {
            ...row,
            'sync_id': portable,
            'entry_id': entryIds[row['entry_id']]!,
            'file_name': '',
            'local_path': '',
            'is_deleted': 1,
          });
        }
        String? originalPath;
        if (avatar != null && original != null) {
          originalPath = await ProfileStore.writeOriginal(
            storageRoot,
            await _decodeMedia(original),
          );
          staged.add(File(originalPath).parent);
        }
        final values = {
          'display_name': profile['display_name'],
          if (profile['created_at'] != null)
            'created_at': profile['created_at'],
          'avatar_image': avatar == null ? null : base64Decode(avatar),
          'avatar_original_path': originalPath,
        };
        final updated = await txn.update(
          'profiles',
          values,
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        if (updated == 0) {
          await txn.insert('profiles', {
            'user_id': userId,
            'created_at': DateTime.now().toUtc().toIso8601String(),
            ...values,
          });
        }
        await afterRestore?.call(txn);
      });
    } catch (_) {
      for (final folder in staged) {
        try {
          await folder.delete(recursive: true);
        } on FileSystemException {
          // Keep the original restore error if temporary files cannot be removed.
        }
      }
      rethrow;
    }
    for (final file in oldAttachments) {
      await const EntryPhotoStorage().removeAttachment(
        file['local_path'] as String,
        fileType: file['file_type'] as String,
      );
    }
    await ProfileStore.removeOriginal(storageRoot, oldAvatar);
  }

  static Object? _decode(String snapshot) => jsonDecode(snapshot);

  Future<void> rewritePrivateEntries(
    Transaction transaction,
    String expected,
    Iterable<Map<String, dynamic>> entries,
  ) async {
    if ((await _snapshot(transaction)).content != expected) {
      throw StateError(
        'The guest workspace changed during transfer. Both copies are safe.',
      );
    }
    final user = await _userId(transaction);
    final batch = transaction.batch();
    for (final entry in entries) {
      batch.update(
        'entries',
        {'private_content': entry['private_content']},
        where: 'sync_id = ? AND is_deleted = 0 AND category_id IN (SELECT id FROM categories WHERE user_id = ?)',
        whereArgs: [entry['id'], user],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, Object?>>> removeTransferredEntries(
    String expected,
    Set<int> transferred, {
    required bool removeCategories,
  }) async {
    final db = await _helper.database;
    return db.transaction((txn) async {
      final user = await _userId(txn);
      final current = await _snapshot(txn);
      if (current.content != expected) {
        throw StateError(
          'The guest workspace changed during transfer. Both copies are safe.',
        );
      }
      final oldFiles = <Map<String, Object?>>[];
      final entries = await txn.rawQuery(
        '''
        SELECT entries.id, entries.sync_id, entries.is_deleted
        FROM entries JOIN categories ON entries.category_id = categories.id
        WHERE categories.user_id = ?
      ''',
        [user],
      );
      final deletions = txn.batch();
      var hasDeletions = false;
      for (final entry in entries) {
        if (!transferred.contains(entry['sync_id']) &&
            !(removeCategories && entry['is_deleted'] == 1)) {
          continue;
        }
        oldFiles.addAll(
          await txn.query(
            'media_attachments',
            columns: ['local_path', 'file_type'],
            where: "entry_id = ? AND local_path != ''",
            whereArgs: [entry['id']],
          ),
        );
        deletions.delete('entries', where: 'id = ?', whereArgs: [entry['id']]);
        hasDeletions = true;
      }
      if (hasDeletions) await deletions.commit(noResult: true);
      if (removeCategories) {
        await txn.rawDelete(
          '''
          DELETE FROM categories
          WHERE user_id = ? AND is_default = 0 AND NOT EXISTS (
            SELECT 1 FROM entries JOIN categories ON entries.category_id = categories.id
            WHERE categories.user_id = ?
          )
        ''',
          [user, user],
        );
      }
      await txn.delete(
        'guest_transfer',
        where: 'guest_id = ?',
        whereArgs: [user],
      );
      return oldFiles;
    });
  }

  static Future<Uint8List> _decodeMedia(String value) async =>
      value.length >= 256 * 1024
      ? compute(base64Decode, value)
      : base64Decode(value);

  Future<int> _userId(DatabaseExecutor db) async =>
      _helper.activeUserId ??
      (await db.query(
            'users',
            columns: ['id'],
            where: 'google_account_id IS NULL',
            orderBy: 'id',
            limit: 1,
          )).single['id']
          as int;

  List<Map<String, Object?>> _rows(
    Map<String, dynamic> data,
    String key,
    List<String> columns,
  ) {
    final rows = data[key];
    if (rows is! List || rows.any((row) => row is! Map<String, dynamic>)) {
      throw FormatException('Invalid workspace data for $key.');
    }
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        {for (final column in columns) column: row[column]},
    ];
  }
}
