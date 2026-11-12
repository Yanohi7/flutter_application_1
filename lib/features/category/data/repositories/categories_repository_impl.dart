// Fulfill the domain category repository contract by delegating to local storage

import '../../domain/entities/entry_category.dart';
import '../../domain/repositories/categories_repository.dart';
import '../../domain/results/category_deletion_summary.dart';
import '../datasources/category_local_datasource.dart';

class CategoriesRepositoryImpl implements CategoriesRepository {
  final CategoryLocalDataSource localDataSource;

  // The app injects this implementation into use cases through CategoriesRepository
  CategoriesRepositoryImpl(this.localDataSource);

  // Models extend EntryCategory, so callers can use them through the domain type
  @override
  Future<List<EntryCategory>> getCategories() =>
      localDataSource.getCategories();

  @override
  Future<EntryCategory> createCategory({required String name, int? parentId}) =>
      localDataSource.createCategory(name: name, parentId: parentId);

  @override
  Future<EntryCategory> updateCategory({
    required int id,
    required String name,
    required int? parentId,
  }) => localDataSource.updateCategory(id: id, name: name, parentId: parentId);

  @override
  Future<CategoryDeletionSummary> getDeletionSummary(int id) =>
      localDataSource.getDeletionSummary(id);

  @override
  Future<void> deleteCategory(int id) => localDataSource.deleteCategory(id);
}
