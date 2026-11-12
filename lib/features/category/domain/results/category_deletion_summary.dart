// Carry category and entry counts for a deletion confirmation without storing UI message text

class CategoryDeletionSummary {
  final int categoryId;

  // Count all nested categories without including the category selected for deletion
  final int descendantCategoryCount;
  final int entryCount;

  const CategoryDeletionSummary({
    required this.categoryId,
    required this.descendantCategoryCount,
    required this.entryCount,
  });

  // Add the selected category when the UI needs the full affected category count
  int get totalCategoryCount => descendantCategoryCount + 1;
}
