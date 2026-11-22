import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../../core/security/private_content_store.dart';
import 'datasources/drive_workspace_store.dart';

bool sameWorkspacePrivateKey(String first, String second) {
  if (first == second) return true;
  final firstId = (jsonDecode(first) as Map<String, dynamic>)['keyId'];
  final secondId = (jsonDecode(second) as Map<String, dynamic>)['keyId'];
  return firstId is String && firstId == secondId;
}

Future<void> reencryptWorkspacePrivateEntries(
  List<Map<String, dynamic>> entries,
  SecretKey source,
  SecretKey target,
) async {
  for (final entry in entries) {
    if (entry['is_deleted'] != 0) continue;
    final encrypted = entry['private_content'] as String;
    if (encrypted.isEmpty) continue;
    final plaintext = await PrivateContentStore.decrypt(encrypted, source);
    entry['private_content'] = await PrivateContentStore.encrypt(
      plaintext,
      target,
    );
  }
}

/// Keeps local rows and imports current Drive entries without overwriting edits.
String mergeWorkspaceCopies(
  String local,
  List<String> remoteCopies, {
  String? importFolder,
}) {
  final merged = _decode(local);
  final categories = _rows(merged, 'categories');
  final entries = _rows(merged, 'entries');
  final attachments = _rows(merged, 'attachments');
  final remotes = remoteCopies.map(_decode).toList();
  final deletions = <(Object?, Object?), Map<String, dynamic>>{};
  final attachmentDeletions =
      <(Object?, Object?, Object?, Object?), Map<String, dynamic>>{};
  (Object?, Object?) identity(Map<String, dynamic> entry) =>
      (entry['id'], entry['created_at']);
  (Object?, Object?, Object?, Object?) attachmentIdentity(
    Map<String, dynamic> attachment,
    Map<Object?, Object?> entryDates,
  ) => (
    attachment['id'],
    attachment['created_at'],
    attachment['entry_id'],
    entryDates[attachment['entry_id']],
  );
  if (importFolder == null) {
    for (final data in [merged, ...remotes]) {
      final entryDates = <Object?, Object?>{};
      for (final entry in _rows(data, 'entries')) {
        if (entry['is_deleted'] != 0) deletions[identity(entry)] = entry;
        entryDates[entry['id']] = entry['created_at'];
      }
      for (final marker in _rows(data, 'attachmentDeletions')) {
        attachmentDeletions[attachmentIdentity(marker, entryDates)] = marker;
      }
    }
  }
  if (deletions.isNotEmpty) {
    final localIds = entries.map((entry) => entry['id']).toSet();
    final defaultCategory = categories.firstWhere(
      (row) => row['is_default'] == 1,
    );
    final deletedIds = <Object?>{};
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      final deletion = deletions[identity(entry)];
      if (deletion == null) continue;
      deletedIds.add(entry['id']);
      entries[index] = _deletedEntry(deletion, entry['category_id']);
    }
    for (final deletion in deletions.values) {
      if (localIds.add(deletion['id'])) {
        entries.add(_deletedEntry(deletion, defaultCategory['id']));
      }
    }
    attachments.removeWhere((row) => deletedIds.contains(row['entry_id']));
  }
  final originalEntries = {for (final entry in entries) entry['id']: entry};
  final entryDates = {
    for (final entry in entries) entry['id']: entry['created_at'],
  };
  attachments.removeWhere(
    (row) =>
        attachmentDeletions.containsKey(attachmentIdentity(row, entryDates)),
  );
  final usedAttachmentIds = attachments.map((row) => row['id']).toSet();
  final attachmentMarkers = importFolder != null
      ? _rows(merged, 'attachmentDeletions')
      : [
          for (final MapEntry(key: key, value: marker)
              in attachmentDeletions.entries)
            if (originalEntries[key.$3]?['is_deleted'] == 0 &&
                entryDates[key.$3] == key.$4 &&
                usedAttachmentIds.add(marker['id']))
              marker,
        ];
  var nextCategory = _maxId(categories) + 1;
  var nextEntry = _maxId(entries) + 1;
  var nextAttachment = _maxId([...attachments, ...attachmentMarkers]) + 1;
  final takenNames = {
    for (final row in categories)
      if (row['parent_id'] == null && row['is_deleted'] == 0)
        (row['name'] as String).toLowerCase(),
  };
  final originalAttachments = _byEntry(attachments);
  final originalCategories = {
    for (final category in categories) category['id']: category,
  };
  final importedVersions = <String>{};
  var copyNumber = 0;

  for (final data in remotes) {
    final remoteCategories = _rows(
      data,
      'categories',
    ).where((row) => row['is_deleted'] == 0).toList();
    final liveCategoryIds = remoteCategories.map((row) => row['id']).toSet();
    final remoteRows = _rows(data, 'entries');
    final remoteDates = {
      for (final entry in remoteRows) entry['id']: entry['created_at'],
    };
    final remoteAttachments = _byEntry(
      _rows(data, 'attachments')
          .where(
            (row) => !attachmentDeletions.containsKey(
              attachmentIdentity(row, remoteDates),
            ),
          )
          .toList(),
    );
    final remoteEntries = remoteRows.where((entry) {
      if (entry['is_deleted'] != 0 ||
          deletions.containsKey(identity(entry)) ||
          !liveCategoryIds.contains(entry['category_id'])) {
        return false;
      }
      final id = entry['id'];
      return importFolder != null ||
          jsonEncode(originalEntries[id]) != jsonEncode(entry) ||
          jsonEncode(originalAttachments[id]) !=
              jsonEncode(remoteAttachments[id]);
    }).toList();
    final byId = {for (final row in remoteCategories) row['id']: row};
    void importEntry(Map<String, dynamic> entry, Object? categoryId) {
      final id = nextEntry++;
      entries.add({...entry, 'id': id, 'category_id': categoryId});
      for (final attachment in remoteAttachments[entry['id']] ?? const []) {
        attachments.add({
          ...attachment,
          'id': nextAttachment++,
          'entry_id': id,
        });
      }
    }

    final copies = <Map<String, dynamic>>[];
    for (final entry in remoteEntries) {
      final categoryId = entry['category_id'];
      final localCategory = originalCategories[categoryId];
      final existing = originalEntries[entry['id']];
      if (importFolder == null &&
          !importedVersions.add(
            jsonEncode([
              entry,
              byId[categoryId],
              remoteAttachments[entry['id']],
            ]),
          )) {
        continue;
      }
      if (importFolder == null &&
          (existing == null || identity(existing) != identity(entry)) &&
          localCategory?['is_deleted'] == 0 &&
          jsonEncode(localCategory) == jsonEncode(byId[categoryId])) {
        importEntry(entry, categoryId);
      } else {
        copies.add(entry);
      }
    }
    final neededCategories = {
      for (final row in remoteCategories)
        if (importFolder != null ||
            jsonEncode(originalCategories[row['id']]) != jsonEncode(row))
          row['id'],
      for (final entry in copies) entry['category_id'],
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
          ? (importFolder ?? 'Google Drive copies')
          : '${importFolder ?? 'Google Drive copies'} $copyNumber';
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
    for (final entry in copies) {
      importEntry(entry, categoryIds[entry['category_id']] ?? root);
    }
  }

  return jsonEncode({
    for (final entry in merged.entries)
      if (entry.key != 'attachmentDeletions') entry.key: entry.value,
    'categories': categories,
    'entries': entries
      ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int)),
    'attachments': attachments,
    if (attachmentMarkers.isNotEmpty)
      'attachmentDeletions': attachmentMarkers
        ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int)),
  });
}

Map<String, dynamic> _deletedEntry(
  Map<String, dynamic> entry,
  Object? categoryId,
) => {
  ...entry,
  'category_id': categoryId,
  'title': '',
  'content': '',
  'private_content': '',
  'is_pinned': 0,
  'is_favorite': 0,
};

Map<String, dynamic> _decode(String snapshot) {
  final data = jsonDecode(snapshot);
  if (data is! Map<String, dynamic> || data['version'] != 1) {
    throw const DriveSyncException('This workspace version cannot be merged.');
  }
  return data;
}

List<Map<String, dynamic>> _rows(Map<String, dynamic> data, String name) =>
    (data[name] as List? ?? const []).cast<Map<String, dynamic>>().toList();

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
