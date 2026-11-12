// Save entry edits or update individual flags.

import '../entities/entry.dart';
import '../repositories/entries_repository.dart';

class UpdateEntry {
  // Receive the concrete repository through its domain contract when the app builds this use case
  final EntriesRepository repository;
  UpdateEntry(this.repository);

  Future<void> call(Entry entry, {bool allowUntitled = false}) {
    if (entry.id == null) {
      throw ArgumentError('The entry has not been created yet.');
    }
    if (!allowUntitled && (entry.title?.trim().isEmpty ?? true)) {
      throw ArgumentError('Enter an entry title.');
    }
    return repository.updateEntry(entry);
  }

  Future<void> flags(int id, {bool? pinned, bool? favorite}) =>
      repository.updateEntryFlags(id, pinned: pinned, favorite: favorite);
}
