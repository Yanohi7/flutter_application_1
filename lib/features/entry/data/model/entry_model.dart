// Translate between domain entries and SQLite row maps, including dates and boolean flags

import '../../domain/entities/entry.dart';
import '../../domain/entities/media_attachment.dart';

/// Convert SQLite rows to and from Entry in data rather than domain
class EntryModel extends Entry {
  const EntryModel({
    super.id,
    required super.categoryId,
    super.categoryName,
    super.title,
    required super.content,
    super.privateContent,
    required super.createdAt,
    required super.updatedAt,
    super.isPinned,
    super.isFavorite,
    super.isDeleted,
    super.attachments,
  });

  /// Read one row from a SQL query result
  factory EntryModel.fromMap(
    Map<String, Object?> map, {
    List<MediaAttachment> attachments = const [],
  }) => EntryModel(
    attachments: attachments,
    id: map['id'] as int,
    categoryId: map['category_id'] as int,
    categoryName: map['category_name'] as String? ?? 'General',
    title: map['title'] as String?,
    content: map['content'] as String,
    privateContent: map['private_content'] as String? ?? '',
    // Convert stored ISO date strings back to DateTime objects used by sorting and display
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
    isPinned: map['is_pinned'] == 1, // SQLite stores booleans as 0 or 1
    isFavorite: map['is_favorite'] == 1,
    isDeleted: map['is_deleted'] == 1,
  );

  /// The repository receives an entity; the datasource needs a model
  factory EntryModel.fromEntity(Entry entry) => EntryModel(
    id: entry.id,
    categoryId: entry.categoryId,
    categoryName: entry.categoryName,
    title: entry.title,
    content: entry.content,
    privateContent: entry.privateContent,
    createdAt: entry.createdAt,
    updatedAt: entry.updatedAt,
    isPinned: entry.isPinned,
    isFavorite: entry.isFavorite,
    isDeleted: entry.isDeleted,
    attachments: entry.attachments,
  );

  /// The keys match the columns in the existing entries table
  Map<String, Object?> toMap() => {
    if (id != null) 'id': id, // SQLite generates the ID for a new entry
    'category_id': categoryId,
    'title': title,
    'content': content,
    'private_content': privateContent,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'is_pinned': isPinned ? 1 : 0,
    'is_favorite': isFavorite ? 1 : 0,
    'is_deleted': isDeleted ? 1 : 0,
    // Do not write categoryName: the name is stored in the categories table
  };
}
