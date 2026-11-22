import '../../domain/entities/entry.dart';

/// Selects an ordering algorithm without changing how entry queries are filtered.
abstract class EntrySortStrategy {
  const EntrySortStrategy();

  static EntrySortStrategy forOption(String option) => switch (option) {
    'Oldest' => const _OldestFirst(),
    'A-Z' => const _TitleAscending(),
    'Z-A' => const _TitleDescending(),
    'Last edited' => const _LastEditedFirst(),
    _ => const _NewestFirst(),
  };

  Comparator<Entry> comparator(List<Entry> entries);

  void sort(List<Entry> entries) {
    final compare = comparator(entries);
    entries.sort((first, second) {
      if (first.isPinned != second.isPinned) {
        return first.isPinned ? -1 : 1;
      }
      final order = compare(first, second);
      return order != 0 ? order : (first.id ?? 0).compareTo(second.id ?? 0);
    });
  }
}

class _NewestFirst extends EntrySortStrategy {
  const _NewestFirst();

  @override
  Comparator<Entry> comparator(List<Entry> entries) =>
      (first, second) => second.createdAt.compareTo(first.createdAt);
}

class _OldestFirst extends EntrySortStrategy {
  const _OldestFirst();

  @override
  Comparator<Entry> comparator(List<Entry> entries) =>
      (first, second) => first.createdAt.compareTo(second.createdAt);
}

class _TitleAscending extends EntrySortStrategy {
  const _TitleAscending();

  @override
  Comparator<Entry> comparator(List<Entry> entries) {
    final titles = {
      for (final entry in entries) entry: (entry.title ?? '').toLowerCase(),
    };
    return (first, second) => titles[first]!.compareTo(titles[second]!);
  }
}

class _TitleDescending extends EntrySortStrategy {
  const _TitleDescending();

  @override
  Comparator<Entry> comparator(List<Entry> entries) {
    final titles = {
      for (final entry in entries) entry: (entry.title ?? '').toLowerCase(),
    };
    return (first, second) => titles[second]!.compareTo(titles[first]!);
  }
}

class _LastEditedFirst extends EntrySortStrategy {
  const _LastEditedFirst();

  @override
  Comparator<Entry> comparator(List<Entry> entries) =>
      (first, second) => second.updatedAt.compareTo(first.updatedAt);
}
