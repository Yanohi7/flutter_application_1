// Validate a new category name before requesting creation through the repository contract

import '../entities/entry_category.dart';
import '../repositories/categories_repository.dart';

class CreateCategory {
  // Receive the concrete repository through its domain contract when the app builds this use case
  final CategoriesRepository repository;

  CreateCategory(this.repository);

  Future<EntryCategory> call({required String name, int? parentId}) {
    // Reject blank names before involving storage while hierarchy checks remain in the data source
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      throw ArgumentError('Enter the category name!');
    }

    return repository.createCategory(name: cleanName, parentId: parentId);
  }
}
