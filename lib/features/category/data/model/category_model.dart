// Convert a SQLite category row into an object that also satisfies the domain entity type

import '../../domain/entities/entry_category.dart';

class CategoryModel extends EntryCategory {
  const CategoryModel({
    required super.id,
    required super.name,
    super.parentId,
    super.isDefault,
  });

  // Translate database column names and integer flags into typed domain fields
  factory CategoryModel.fromMap(Map<String, Object?> map) {
    return CategoryModel(
      id: map['id'] as int,
      name: map['name'] as String,
      parentId: map['parent_id'] as int?,
      isDefault: map['is_default'] == 1,
    );
  }
}
