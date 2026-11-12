// Format entry timestamps as local day, month and year labels

enum EntryDateFormat { full, shortYear, dayAndMonth }

/// Format a short local date without adding the intl dependency
String formatEntryDate(
  DateTime value, {
  EntryDateFormat format = EntryDateFormat.full,
}) {
  final date = value.toLocal(); // Convert UTC timestamps to local time
  // Pad single-digit day and month values so dates have a consistent width
  String two(int number) => number.toString().padLeft(2, '0');
  final dayAndMonth = '${two(date.day)}.${two(date.month)}';
  return switch (format) {
    EntryDateFormat.full => '$dayAndMonth.${date.year}',
    EntryDateFormat.shortYear => '$dayAndMonth.${two(date.year % 100)}',
    EntryDateFormat.dayAndMonth => dayAndMonth,
  };
}
