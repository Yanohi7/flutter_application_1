import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/category/domain/entities/entry_category.dart';
import 'package:flutter_application_1/features/category/domain/repositories/categories_repository.dart';

class TestCategoriesRepository extends Fake implements CategoriesRepository {
  final categories = <EntryCategory>[
    const EntryCategory(id: 1, name: 'General', isDefault: true),
    const EntryCategory(id: 2, name: 'Work'),
    const EntryCategory(id: 3, name: 'Projects', parentId: 2),
  ];
  bool failSave = false;

  @override
  Future<List<EntryCategory>> getCategories() async => List.of(categories);

  @override
  Future<EntryCategory> createCategory({
    required String name,
    int? parentId,
  }) async {
    if (failSave) throw StateError('Storage unavailable');
    final category = EntryCategory(
      id: categories.length + 1,
      name: name,
      parentId: parentId,
    );
    categories.add(category);
    return category;
  }

  @override
  Future<EntryCategory> updateCategory({
    required int id,
    required String name,
    required int? parentId,
  }) async {
    if (failSave) throw StateError('Storage unavailable');
    final index = categories.indexWhere((item) => item.id == id);
    final category = EntryCategory(
      id: id,
      name: name,
      parentId: parentId,
      isDefault: categories[index].isDefault,
    );
    categories[index] = category;
    return category;
  }
}
