import '../../domain/entities/entry.dart';
import 'entry_filter_sheet.dart';
import 'entry_formatted_content.dart';

/// Applies the same query semantics to navigation, search, and content filters.
List<Entry> queryEntries(
  List<Entry> entries, {
  EntryViewOptions options = const EntryViewOptions(),
  String query = '',
  int? categoryId,
  bool globalSearch = false,
  bool favoritesOnly = false,
  DateTime? now,
}) {
  final search = query.trim().toLowerCase();
  final range = _dateRange(options.time, now);
  final result = entries.where((entry) {
    if (categoryId != null &&
        !(globalSearch && search.isNotEmpty) &&
        entry.categoryId != categoryId) {
      return false;
    }
    if (categoryId == null && favoritesOnly && !entry.isFavorite) return false;
    if (range != null &&
        (entry.createdAt.isBefore(range.start) ||
            !entry.createdAt.isBefore(range.end))) {
      return false;
    }
    final matchesType = switch (options.content) {
      'Checklist' => entryHasChecklist(entry.content),
      'Image' => entry.attachments.any(
        (item) => item.fileType == 'photo' || item.fileType == 'image',
      ),
      'Audio' => entry.attachments.any((item) => item.fileType == 'audio'),
      'File' => entry.attachments.any(
        (item) => const ['document', 'file', 'video'].contains(item.fileType),
      ),
      _ => true,
    };
    if (!matchesType) return false;
    return search.isEmpty ||
        '${entry.title ?? ''} ${entrySearchText(entry.content)}'
            .toLowerCase()
            .contains(search);
  }).toList();
  final titles = options.sort == 'A–Z' || options.sort == 'Z–A'
      ? {for (final entry in result) entry: (entry.title ?? '').toLowerCase()}
      : const <Entry, String>{};
  result.sort((a, b) {
    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
    final order = switch (options.sort) {
      'Oldest' => a.createdAt.compareTo(b.createdAt),
      'A–Z' => titles[a]!.compareTo(titles[b]!),
      'Z–A' => titles[b]!.compareTo(titles[a]!),
      'Last edited' => b.updatedAt.compareTo(a.updatedAt),
      _ => b.createdAt.compareTo(a.createdAt),
    };
    return order != 0 ? order : (a.id ?? 0).compareTo(b.id ?? 0);
  });
  return result;
}

({DateTime start, DateTime end})? _dateRange(String filter, DateTime? now) {
  if (filter == 'All time') return null;
  final date = (now ?? DateTime.now()).toLocal();
  final year = date.year;
  final month = date.month;
  final day = date.day;
  final monday = day - date.weekday + 1;
  return switch (filter) {
    'Today' => (
      start: DateTime(year, month, day),
      end: DateTime(year, month, day + 1),
    ),
    'This week' => (
      start: DateTime(year, month, monday),
      end: DateTime(year, month, monday + 7),
    ),
    'This month' => (
      start: DateTime(year, month),
      end: DateTime(year, month + 1),
    ),
    _ => null,
  };
}
