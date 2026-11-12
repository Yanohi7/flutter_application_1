// Validate a new entry, resolve its category and return the saved entry with its generated ID

import '../entities/entry.dart';
import '../entities/media_attachment.dart';
import '../repositories/entries_repository.dart';

/// Create an entry: validate its title, resolve its category, then save
class CreateEntry {
  // Receive the concrete repository through its domain contract when the app builds this use case
  final EntriesRepository repository;
  CreateEntry(this.repository);

  Future<Entry> call({
    required String title,
    required String content,
    String privateContent = '',
    bool isPinned = false,
    bool isFavorite = false,
    List<MediaAttachment> attachments = const [],
    ({int id, String name})? category,
  }) async {
    final cleanTitle = title.trim(); // Trim leading and trailing whitespace
    if (cleanTitle.isEmpty) throw ArgumentError('Enter an entry title.');
    // Use the provided category when present and otherwise await a non-null default
    final targetCategory = category ?? await repository.getDefaultCategory();
    final now = DateTime.now(); // Both timestamps are the same for a new entry
    final entry = Entry(
      categoryId: targetCategory.id,
      categoryName:
          targetCategory.name, // Keep the name of the existing category
      title: cleanTitle,
      content: content.trim(),
      privateContent: privateContent,
      createdAt: now,
      updatedAt: now,
      isPinned: isPinned,
      isFavorite: isFavorite,
      attachments: attachments,
    );
    final id = await repository.createEntry(
      entry,
    ); // Wait for INSERT to complete
    return entry.copyWith(
      id: id,
    ); // The UI immediately receives the saved entry
  }
}
