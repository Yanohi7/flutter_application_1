// Represent entry content, category, timestamps and flags independently of Flutter and SQLite

import 'media_attachment.dart';

/// A pure entity that has no dependency on Flutter or SQLite
class Entry {
  final int? id; // The ID does not exist before INSERT
  final int categoryId; // Links the entry to its category in storage
  final String categoryName; // The category name displayed on the card
  final String? title; // Older entries may not have a title
  // Only encrypted payloads belong here, never decrypted private text
  final String privateContent;
  final String content; // The main entry text
  final DateTime createdAt; // Keep this timestamp unchanged when editing
  final DateTime updatedAt; // Use this timestamp to sort entries
  final bool isPinned; // Pinned entries appear first
  final bool isFavorite; // The flag used by the Favorites filter
  final bool
  isDeleted; // Read legacy flags and entries hidden by category deletion
  final List<MediaAttachment> attachments;

  const Entry({
    this.id,
    required this.categoryId,
    this.categoryName = 'General',
    this.title,
    required this.content,
    this.privateContent = '',
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.isFavorite = false,
    this.isDeleted = false,
    this.attachments = const [],
  });

  /// Return a new version of the entry without modifying the original
  Entry copyWith({
    int? id,
    int? categoryId,
    String? categoryName,
    String? title,
    String? content,
    String? privateContent,
    DateTime? updatedAt,
    bool? isPinned,
    bool? isFavorite,
    List<MediaAttachment>? attachments,
  }) {
    return Entry(
      id: id ?? this.id,
      // Keep the previous value when no replacement is provided
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      title: title ?? this.title,
      content: content ?? this.content,
      privateContent: privateContent ?? this.privateContent,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      isDeleted: isDeleted,
      attachments: attachments ?? this.attachments,
    );
  }
}
