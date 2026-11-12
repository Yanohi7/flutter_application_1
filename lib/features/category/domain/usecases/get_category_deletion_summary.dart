// Request deletion impact counts without deleting any categories or entries

import '../results/category_deletion_summary.dart';
import '../repositories/categories_repository.dart';

class GetCategoryDeletionSummary {
  // Receive the concrete repository through its domain contract when the app builds this use case
  final CategoriesRepository repository;

  GetCategoryDeletionSummary(this.repository);

  Future<CategoryDeletionSummary> call({required int id}) =>
      repository.getDeletionSummary(id);
}
