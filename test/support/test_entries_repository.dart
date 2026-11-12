import 'dart:async';

import 'package:flutter_application_1/features/entry/domain/entities/entry.dart';
import 'package:flutter_application_1/features/entry/domain/repositories/entries_repository.dart';

/// A widget-test repository that controls delays and failures.
class TestEntriesRepository implements EntriesRepository {
  final List<Entry> entries;
  bool failSave = false;
  bool failLoad = false;
  Completer<void>? pendingSave;
  int createCalls = 0;
  TestEntriesRepository([List<Entry> seed = const []]) : entries = [...seed];

  @override
  Future<List<Entry>> getEntries({int? categoryId}) async {
    if (failLoad) throw StateError('Test load failure');
    return [...entries];
  }

  @override
  Future<Entry> getEntryById(int id) async =>
      entries.firstWhere((e) => e.id == id);
  @override
  Future<({int id, String name})> getDefaultCategory() async =>
      (id: 1, name: 'General');
  @override
  Future<int> createEntry(Entry entry) async {
    createCalls++;
    if (pendingSave != null) await pendingSave!.future;
    if (failSave) throw StateError('Test write failure');
    final id = entries.length + 1;
    entries.add(entry.copyWith(id: id));
    return id;
  }

  @override
  Future<void> updateEntry(Entry entry) async {
    if (failSave) throw StateError('Test write failure');
    entries[entries.indexWhere((e) => e.id == entry.id)] = entry;
  }

  @override
  Future<void> updateEntryFlags(int id, {bool? pinned, bool? favorite}) async {
    if (pendingSave != null) await pendingSave!.future;
    if (failSave) throw StateError('Test write failure');
    final index = entries.indexWhere((entry) => entry.id == id);
    entries[index] = entries[index].copyWith(
      isPinned: pinned,
      isFavorite: favorite,
    );
  }

  @override
  Future<void> deleteEntry(int id) async =>
      entries.removeWhere((e) => e.id == id);
}

/// Long text checks preview truncation and stable grid height.
Entry sampleEntry(int id, {bool pinned = false, bool favorite = false}) =>
    Entry(
      id: id,
      categoryId: 1,
      title: 'Entry $id — a long title for layout testing',
      content:
          'Ideas for the next project. Write a plan, review the material, '
              'and try a new approach. ' *
          5,
      createdAt: DateTime(2026, 10, 19),
      updatedAt: DateTime(2026, 10, 19, id),
      isPinned: pinned,
      isFavorite: favorite,
    );
