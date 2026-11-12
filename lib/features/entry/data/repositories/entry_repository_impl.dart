// Implement entry repository operations and convert domain entities into local storage models

import '../../domain/entities/entry.dart';
import '../../domain/repositories/entries_repository.dart';
import '../datasources/entry_local_datasource.dart';
import '../model/entry_model.dart';

/// Implement the domain contract using the local datasource
class EntryRepositoryImpl implements EntriesRepository {
  // Convert data at this boundary so the domain never needs to import EntryModel
  final EntryLocalDataSource localDataSource;
  EntryRepositoryImpl(this.localDataSource);

  @override
  Future<List<Entry>> getEntries({int? categoryId}) =>
      localDataSource.getEntries(categoryId: categoryId);

  @override
  Future<Entry> getEntryById(int id) => localDataSource.getEntryById(id);

  @override
  Future<({int id, String name})> getDefaultCategory() =>
      localDataSource.getDefaultCategory();

  @override
  Future<int> createEntry(Entry entry) =>
      localDataSource.insertEntry(EntryModel.fromEntity(entry)); // Entity → Model

  @override
  Future<void> updateEntry(Entry entry) =>
      localDataSource.updateEntry(EntryModel.fromEntity(entry));

  @override
  Future<void> updateEntryFlags(int id, {bool? pinned, bool? favorite}) =>
      localDataSource.updateEntryFlags(id, pinned: pinned, favorite: favorite);

  @override
  Future<void> deleteEntry(int id) => localDataSource.deleteEntry(id);
}
