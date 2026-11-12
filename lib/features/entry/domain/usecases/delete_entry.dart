// Request deletion of a saved entry through the repository contract

import '../repositories/entries_repository.dart';

/// The UI asks for confirmation; this use case performs deletion
class DeleteEntry {
  // Receive the concrete repository through its domain contract when the app builds this use case
  final EntriesRepository repository;
  DeleteEntry(this.repository);

  Future<void> call(int id) => repository.deleteEntry(id);
}
