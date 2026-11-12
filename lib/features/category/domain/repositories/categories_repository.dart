// Declare category operations that use cases may request without choosing a storage implementation

import '../entities/entry_category.dart';
import '../results/category_deletion_summary.dart';

// Calls on this type run the injected implementation, not a second intermediate repository object
abstract class CategoriesRepository {
  Future<List<EntryCategory>> getCategories();

  Future<EntryCategory> createCategory({required String name, int? parentId});

  Future<EntryCategory> updateCategory({
    required int id,
    required String name,
    required int? parentId,
  });

  // Calculate impact separately so the UI can explain deletion before requesting it
  Future<CategoryDeletionSummary> getDeletionSummary(int id);

  Future<void> deleteCategory(int id);
}
