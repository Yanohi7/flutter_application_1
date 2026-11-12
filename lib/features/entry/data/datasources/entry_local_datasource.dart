// Execute entry SQL queries and writes and retrieve category details for saved entries

import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../domain/entities/media_attachment.dart';
import 'entry_photo_storage.dart';
import '../model/entry_model.dart';

/// The entry feature accesses local storage through this datasource
abstract class EntryLocalDataSource {
  Future<List<EntryModel>> getEntries({int? categoryId});
  Future<EntryModel> getEntryById(int id);
  Future<({int id, String name})> getDefaultCategory();
  Future<int> insertEntry(EntryModel entry);
  Future<void> updateEntry(EntryModel entry);
  Future<void> updateEntryFlags(int id, {bool? pinned, bool? favorite});
  Future<void> deleteEntry(int id);
}

class EntryLocalDataSourceImpl implements EntryLocalDataSource {
  final DatabaseHelper
  dbHelper; // Receive the dependency through the constructor
  EntryLocalDataSourceImpl(this.dbHelper);

  // JOIN includes the actual category name without changing the table schema
  static const _select = '''
    SELECT entries.*, categories.name AS category_name
    FROM entries JOIN categories ON entries.category_id = categories.id
  ''';

  @override
  Future<List<EntryModel>> getEntries({int? categoryId}) async {
    final db = await dbHelper.database; // Open the database only when needed
    final categoryFilter = categoryId == null
        ? ''
        : ' AND entries.category_id = ?';
    final maps = await db.rawQuery(
      '$_select WHERE entries.is_deleted = 0'
      '$categoryFilter'
      ' ORDER BY entries.is_pinned DESC, entries.updated_at DESC, entries.id DESC',
      [?categoryId], // Pass values separately from SQL
    );
    if (maps.isEmpty) return [];
    final attachments = await db.rawQuery(
      'SELECT media_attachments.* FROM media_attachments '
      'JOIN entries ON entries.id = media_attachments.entry_id '
      'WHERE media_attachments.is_deleted = 0 AND entries.is_deleted = 0'
      '$categoryFilter ORDER BY media_attachments.id',
      [?categoryId],
    );
    final byEntry = <int, List<MediaAttachment>>{};
    for (final row in attachments) {
      final attachment = _attachmentFromRow(row);
      (byEntry[attachment.entryId!] ??= []).add(attachment);
    }
    return [
      for (final row in maps)
        EntryModel.fromMap(row, attachments: byEntry[row['id']] ?? const []),
    ];
  }

  @override
  Future<EntryModel> getEntryById(int id) async {
    final db = await dbHelper.database;
    final rows = await db.rawQuery(
      '$_select WHERE entries.id = ? AND entries.is_deleted = 0',
      [id],
    );
    if (rows.isEmpty) throw StateError('Entry not found.');
    final attachments = await db.query(
      'media_attachments',
      where: 'entry_id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    return EntryModel.fromMap(
      rows.single,
      attachments: attachments.map(_attachmentFromRow).toList(),
    );
  }

  @override
  Future<({int id, String name})> getDefaultCategory() async {
    final id = await dbHelper
        .ensureDefaultCategory(); // Prepare the foreign key before INSERT
    final db = await dbHelper.database;
    final rows = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    // An existing default category may have a different name from General
    return (id: id, name: rows.single['name'] as String);
  }

  @override
  Future<int> insertEntry(EntryModel entry) async {
    final db = await dbHelper.database;
    return db.transaction((txn) async {
      final id = await txn.insert('entries', entry.toMap());
      if (entry.attachments.isNotEmpty) {
        final batch = txn.batch();
        _upsertAttachments(batch, id, entry.attachments);
        await batch.commit(noResult: true);
      }
      return id;
    });
  }

  @override
  Future<void> updateEntry(EntryModel entry) async {
    final db = await dbHelper.database;
    final removed = await db.transaction((txn) async {
      final count = await txn.update(
        'entries',
        entry.toMap(),
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [entry.id],
      );
      if (count != 1) throw StateError('Entry not found.');
      final keptPaths = entry.attachments.map((file) => file.localPath).toSet();
      final rows = await txn.query(
        'media_attachments',
        columns: ['id', 'local_path', 'file_type'],
        where: 'entry_id = ?',
        whereArgs: [entry.id],
      );
      final removed = rows
          .where((row) => !keptPaths.contains(row['local_path']))
          .toList();
      if (entry.attachments.isNotEmpty || removed.isNotEmpty) {
        final batch = txn.batch();
        _upsertAttachments(batch, entry.id!, entry.attachments);
        for (final row in removed) {
          batch.delete(
            'media_attachments',
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
        await batch.commit(noResult: true);
      }
      return removed;
    });
    for (final row in removed) {
      await const EntryPhotoStorage().removeAttachment(
        row['local_path'] as String,
        fileType: row['file_type'] as String,
      );
    }
  }

  @override
  Future<void> updateEntryFlags(int id, {bool? pinned, bool? favorite}) async {
    if (pinned == null && favorite == null) return;
    final db = await dbHelper.database;
    final updated = await db.update(
      'entries',
      {
        if (pinned != null) 'is_pinned': pinned ? 1 : 0,
        if (favorite != null) 'is_favorite': favorite ? 1 : 0,
      },
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    if (updated != 1) throw StateError('Entry not found.');
  }

  // Convert an attachment row to the entity used by the editor and reader
  MediaAttachment _attachmentFromRow(Map<String, Object?> row) =>
      MediaAttachment(
        id: row['id'] as int,
        entryId: row['entry_id'] as int,
        fileType: row['file_type'] as String,
        fileName: row['file_name'] as String,
        displayName: row['display_name'] as String?,
        localPath: row['local_path'] as String,
        mimeType: row['mime_type'] as String?,
        fileSize: row['file_size'] as int?,
      );

  void _upsertAttachments(
    Batch batch,
    int entryId,
    List<MediaAttachment> attachments,
  ) {
    for (final attachment in attachments) {
      if (attachment.id == null) {
        // A previously saved draft may still have no attachment ID in memory.
        batch.rawInsert(
          '''INSERT INTO media_attachments
           (entry_id, file_type, file_name, local_path, mime_type, file_size, created_at, display_name)
           SELECT ?, ?, ?, ?, ?, ?, ?, ?
           WHERE NOT EXISTS (
             SELECT 1 FROM media_attachments WHERE entry_id = ? AND local_path = ?
           )''',
          [
            entryId,
            attachment.fileType,
            attachment.fileName,
            attachment.localPath,
            attachment.mimeType,
            attachment.fileSize,
            DateTime.now().toIso8601String(),
            attachment.displayName,
            entryId,
            attachment.localPath,
          ],
        );
      }
      // Update only metadata owned by this entry, never rename the physical file
      final label = attachment.displayName;
      batch.update(
        'media_attachments',
        {'display_name': label},
        where:
            'entry_id = ? AND local_path = ? AND '
            '${label == null ? 'display_name IS NOT NULL' : 'display_name IS NOT ?'}',
        whereArgs: [entryId, attachment.localPath, ?label],
      );
    }
  }

  @override
  Future<void> deleteEntry(int id) async {
    final db = await dbHelper.database;
    final attachments = await db.transaction((txn) async {
      final rows = await txn.query(
        'media_attachments',
        columns: ['local_path', 'file_type'],
        where: "entry_id = ? AND file_type IN ('photo', 'audio', 'document', 'video')",
        whereArgs: [id],
      );
      // SQLite cascades the deletion to the dependent rows
      await txn.delete('entries', where: 'id = ?', whereArgs: [id]);
      return rows;
    });

    // Clean up attachment copies only after the database transaction has committed
    for (final row in attachments) {
      final photoPath = row['local_path'] as String;
      final references = await db.query(
        'media_attachments',
        columns: ['id'],
        where: 'local_path = ?',
        whereArgs: [photoPath],
        limit: 1,
      );
      if (references.isEmpty) {
        await const EntryPhotoStorage().removeAttachment(
          photoPath,
          fileType: row['file_type'] as String,
        );
      }
    }
  }
}
