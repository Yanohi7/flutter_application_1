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
      columns: _categoryColumns,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id',
    );
    final entries = await txn.rawQuery(
      '''
        SELECT ${_entryColumns.map((column) => 'entries.$column').join(', ')}
        FROM entries JOIN categories
          ON entries.category_id = categories.id WHERE categories.user_id = ?
        ORDER BY entries.id
      ''',
      [userId],
    );
    final attachments = await txn.rawQuery(
      '''
        SELECT media_attachments.id, entry_id, file_type, file_name,
          display_name, local_path, mime_type, media_attachments.created_at
        FROM media_attachments JOIN entries
          ON media_attachments.entry_id = entries.id
        JOIN categories ON entries.category_id = categories.id
        WHERE categories.user_id = ? AND media_attachments.is_deleted = 0
          AND entries.is_deleted = 0 AND categories.is_deleted = 0
        ORDER BY media_attachments.id
      ''',
      [userId],
    );
    final input = (
      profile: profileRow,
      categories: categories,
      entries: entries,
      attachments: attachments,
    );
    final hasMedia =
        attachments.isNotEmpty ||
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
      hasPrivate: entries.any((row) => row['private_content'] != ''),
      isEmpty:
          entries.isEmpty &&
          categories.length == 1 &&
          categories.single['is_default'] == 1 &&
          const ['General', 'Default'].contains(categories.single['name']) &&
          profileRow?['avatar_image'] == null &&
          (profileRow?['display_name'] ?? 'Guest') == 'Guest',
    );
  }

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
      'entries': input.entries,
      'attachments': [
        for (final attachment in input.attachments)
          {
            for (final column in _attachmentColumns) column: attachment[column],
            'bytes': base64Encode(
              await File(attachment['local_path'] as String).readAsBytes(),
            ),
          },
      ],
    });
  }

  Future<void> restore(
    String snapshot, {
    required Directory storageRoot,
    String? replaceExpected,
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
        final hasContent = await txn.rawQuery('''
          SELECT EXISTS(SELECT 1 FROM entries)
            OR EXISTS(SELECT 1 FROM categories WHERE is_default = 0)
            OR EXISTS(SELECT 1 FROM profiles
                       WHERE avatar_image IS NOT NULL)
            AS has_content
        ''');
        if (replaceExpected != null) {
          if ((await _snapshot(txn)).content != replaceExpected) {
            throw StateError('Entries changed during sync. Try again.');
          }
          oldAttachments = await txn.query(
            'media_attachments',
            columns: ['local_path', 'file_type'],
          );
          final profiles = await txn.query(
            'profiles',
            columns: ['avatar_original_path'],
            limit: 1,
          );
          oldAvatar = profiles.singleOrNull?['avatar_original_path'] as String?;
          await txn.delete('entries');
        } else if (hasContent.single['has_content'] == 1) {
          throw StateError('This workspace already contains local data.');
        }
        final userId = await _userId(txn);
        await txn.delete(
          'categories',
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        await txn.execute('PRAGMA defer_foreign_keys = ON;');
        for (final row in categories) {
          await txn.insert('categories', {...row, 'user_id': userId});
        }
        for (final row in entries) {
          await txn.insert('entries', row);
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
          await txn.insert('media_attachments', {
            ...row,
            'local_path': file.path,
            'file_size': bytes.length,
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

  static Future<Uint8List> _decodeMedia(String value) async =>
      value.length >= 256 * 1024
      ? compute(base64Decode, value)
      : base64Decode(value);

  Future<int> _userId(DatabaseExecutor db) async =>
      (await db.query(
            'users',
            columns: ['id'],
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
