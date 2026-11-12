// Request the available categories through the domain repository contract

import '../entities/entry_category.dart';
import '../repositories/categories_repository.dart';

class GetCategories {
  // Receive the concrete repository through its domain contract when the app builds this use case
  final CategoriesRepository repository;

  GetCategories(this.repository);

  Future<List<EntryCategory>> call() => repository.getCategories();
}
