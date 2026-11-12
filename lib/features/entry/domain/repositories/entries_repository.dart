// Define entry storage operations used by domain use cases without importing a data source

import '../entities/entry.dart';

/// The domain contract describes operations without specifying storage details
abstract class EntriesRepository {
  Future<List<Entry>> getEntries({int? categoryId}); // Read the list
  Future<Entry> getEntryById(int id); // Read one entry
  // A named record groups two typed values and is not a map or a list
  Future<({int id, String name})>
  getDefaultCategory(); // The category for the first entry
  Future<int> createEntry(Entry entry); // Return the new SQLite ID
  Future<void> updateEntry(Entry entry); // Update an existing entry
  Future<void> updateEntryFlags(int id, {bool? pinned, bool? favorite});
  Future<void> deleteEntry(int id); // Permanently remove the local entry
}
