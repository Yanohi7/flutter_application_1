// Describe category UI state and derive navigation paths from the selected category ID

import '../../domain/entities/entry_category.dart';

enum CategoryStatus { initial, loading, success, failure }

class CategoryState {
  final CategoryStatus status;

  final List<EntryCategory> categories;

  // Null selects the virtual All Entries view rather than a real database category
  final int? selectedCategoryId;

  final bool isSaving;

  final String? errorMessage;

  CategoryState({
    CategoryStatus status = CategoryStatus.initial,
    List<EntryCategory> categories = const [],
    int? selectedCategoryId,
    bool isSaving = false,
    String? errorMessage,
  }) : this._(
         status: status,
         categories: List<EntryCategory>.unmodifiable(categories),
         selectedCategoryId: selectedCategoryId,
         isSaving: isSaving,
         errorMessage: errorMessage,
       );

  CategoryState._({
    required this.status,
    required this.categories,
    required this.selectedCategoryId,
    required this.isSaving,
    required this.errorMessage,
  });

  static final _indexes =
      Expando<({Map<int, EntryCategory> byId, Map<int, String?> labels})>();

  List<EntryCategory> get selectedPath => _pathTo(selectedCategoryId);

  ({Map<int, EntryCategory> byId, Map<int, String?> labels}) get _index =>
      _indexes[categories] ??= (
        byId: {for (final category in categories) category.id: category},
        labels: <int, String?>{},
      );

  String? pathLabel(int id) => _index.labels.putIfAbsent(id, () {
    final path = _pathTo(id);
    return path.isEmpty ? null : path.map((item) => item.name).join(' → ');
  });

  List<EntryCategory> _pathTo(int? id) {
    final byId = _index.byId;
    final path = <EntryCategory>[];
    final visited = <int>{};

    var currentId = id;

    while (currentId != null && visited.add(currentId)) {
      final category = byId[currentId];

      if (category == null) break;

      path.add(category);

      currentId = category.parentId;
    }

    // The traversal starts at the leaf, so reverse it to show root before child
    return path.reversed.toList();
  }

  // Create a new state while retaining fields that the caller does not replace
  // Explicit clear flags distinguish keeping nullable fields from resetting them to null
  CategoryState copyWith({
    CategoryStatus? status,
    List<EntryCategory>? categories,
    int? selectedCategoryId,
    bool? isSaving,
    String? errorMessage,

    bool clearSelection = false,

    bool clearError = false,
  }) {
    return CategoryState._(
      status: status ?? this.status,
      categories: categories == null || identical(categories, this.categories)
          ? this.categories
          : List<EntryCategory>.unmodifiable(categories),
      selectedCategoryId: clearSelection
          ? null
          : selectedCategoryId ?? this.selectedCategoryId,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
