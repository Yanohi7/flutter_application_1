// Represent a category and its parent relationship without Flutter or database dependencies

class EntryCategory {
  final int id;

  final String name;

  // A null parent identifies a top-level category rather than a missing category
  final int? parentId;

  // The default category is protected from deletion and cannot move under another category
  final bool isDefault;

  const EntryCategory({
    required this.id,
    required this.name,
    this.parentId,
    this.isDefault = false,
  });

  bool get isRoot => parentId == null;
}
