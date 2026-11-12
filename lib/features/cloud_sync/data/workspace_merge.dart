import 'dart:convert';

import 'datasources/drive_workspace_store.dart';

/// Keeps local rows and imports differing live Drive entries as separate copies.
String mergeWorkspaceCopies(String local, List<String> remoteCopies) {
  final merged = _decode(local);
  final categories = _rows(merged, 'categories');
  final entries = _rows(merged, 'entries');
  final attachments = _rows(merged, 'attachments');
  var nextCategory = _maxId(categories) + 1;
  var nextEntry = _maxId(entries) + 1;
  var nextAttachment = _maxId(attachments) + 1;
  final takenNames = {
    for (final row in categories)
      if (row['parent_id'] == null && row['is_deleted'] == 0)
        (row['name'] as String).toLowerCase(),
  };
  final originalEntries = {for (final entry in entries) entry['id']: entry};
  final originalAttachments = _byEntry(attachments);
  final originalCategories = {
    for (final category in categories) category['id']: category,
  };
  var copyNumber = 0;

  for (final remote in remoteCopies) {
    final data = _decode(remote);
    final remoteCategories = _rows(
      data,
      'categories',
    ).where((row) => row['is_deleted'] == 0).toList();
    final liveCategoryIds = remoteCategories.map((row) => row['id']).toSet();
    final remoteAttachments = _byEntry(_rows(data, 'attachments'));
    final remoteEntries = _rows(data, 'entries').where((entry) {
      if (entry['is_deleted'] != 0 ||
          !liveCategoryIds.contains(entry['category_id'])) {
        return false;
      }
      final id = entry['id'];
      return jsonEncode(originalEntries[id]) != jsonEncode(entry) ||
          jsonEncode(originalAttachments[id]) !=
              jsonEncode(remoteAttachments[id]);
    }).toList();
    final byId = {for (final row in remoteCategories) row['id']: row};
    final neededCategories = {
      for (final row in remoteCategories)
        if (jsonEncode(originalCategories[row['id']]) != jsonEncode(row))
          row['id'],
      for (final entry in remoteEntries) entry['category_id'],
    };
    for (final id in neededCategories.toList()) {
      var parent = byId[id]?['parent_id'];
      while (byId.containsKey(parent) && neededCategories.add(parent)) {
        parent = byId[parent]?['parent_id'];
      }
    }
    if (neededCategories.isEmpty) continue;
    final importedCategories = remoteCategories.where(
      (row) => neededCategories.contains(row['id']),
    );

    String name;
    do {
      copyNumber++;
      name = copyNumber == 1
          ? 'Google Drive copies'
          : 'Google Drive copies $copyNumber';
    } while (!takenNames.add(name.toLowerCase()));
    final root = nextCategory++;
    final now = DateTime.now().toUtc().toIso8601String();
    categories.add({
      'id': root,
      'name': name,
      'parent_id': null,
      'is_system': 0,
      'is_default': 0,
      'sort_order': root,
      'is_deleted': 0,
      'deleted_at': null,
      'created_at': now,
      'updated_at': now,
    });
    final categoryIds = {
      for (final row in importedCategories) row['id']: nextCategory++,
    };
    for (final row in importedCategories) {
      categories.add({
        ...row,
        'id': categoryIds[row['id']],
        'parent_id': categoryIds[row['parent_id']] ?? root,
        'is_system': 0,
        'is_default': 0,
      });
    }
    for (final entry in remoteEntries) {
      final id = nextEntry++;
      entries.add({
        ...entry,
        'id': id,
        'category_id': categoryIds[entry['category_id']] ?? root,
      });
      for (final attachment in remoteAttachments[entry['id']] ?? const []) {
        attachments.add({
          ...attachment,
          'id': nextAttachment++,
          'entry_id': id,
        });
      }
    }
  }

  return jsonEncode({
    ...merged,
    'categories': categories,
    'entries': entries,
    'attachments': attachments,
  });
}

Map<String, dynamic> _decode(String snapshot) {
  final data = jsonDecode(snapshot);
  if (data is! Map<String, dynamic> || data['version'] != 1) {
    throw const DriveSyncException('This workspace version cannot be merged.');
  }
  return data;
}

List<Map<String, dynamic>> _rows(Map<String, dynamic> data, String name) =>
    (data[name] as List).cast<Map<String, dynamic>>().toList();

Map<Object?, List<Map<String, dynamic>>> _byEntry(
  List<Map<String, dynamic>> rows,
) {
  final grouped = <Object?, List<Map<String, dynamic>>>{};
  for (final row in rows) {
    (grouped[row['entry_id']] ??= []).add(row);
  }
  return grouped;
}

int _maxId(List<Map<String, dynamic>> rows) => rows.fold(0, (max, row) {
  final id = row['id'] as int;
  return id > max ? id : max;
});
