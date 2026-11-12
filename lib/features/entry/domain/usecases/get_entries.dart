// Load entries through the repository contract without exposing storage details to the Cubit

import '../entities/entry.dart';
import '../repositories/entries_repository.dart';

/// Read entries through the contract without importing SQLite
class GetEntries {
  // Receive the concrete repository through its domain contract when the app builds this use case
  final EntriesRepository repository;
  GetEntries(this.repository);

  Future<List<Entry>> call() => repository.getEntries();
}
