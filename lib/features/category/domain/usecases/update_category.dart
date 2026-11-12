// Validate the edited name and request a category rename or move through the repository

import '../entities/entry_category.dart';
import '../repositories/categories_repository.dart';

class UpdateCategory {
  // Receive the concrete repository through its domain contract when the app builds this use case
  final CategoriesRepository repository;

  UpdateCategory(this.repository);

  Future<EntryCategory> call({
    required int id,
    required String name,
    required int? parentId,
  }) {
    final cleanUpdatedName = name.trim();

    if (cleanUpdatedName.isEmpty) {
      throw ArgumentError("Enter the category name!");
    }

    // A required nullable parent ID explicitly supports moving the category back to the root
    return repository.updateCategory(
      id: id,
      name: cleanUpdatedName,
      parentId: parentId,
    );
  }
}
