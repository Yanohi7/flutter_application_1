// Request category branch deletion through the repository after the UI confirms the action

import '../repositories/categories_repository.dart';

class DeleteCategory {
  // Receive the concrete repository through its domain contract when the app builds this use case
  final CategoriesRepository repository;

  DeleteCategory(this.repository);

  Future<void> call({required int id}) => repository.deleteCategory(id);
}
