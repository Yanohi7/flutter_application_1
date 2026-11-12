import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Publish a verified copy before switching away from the legacy filename.
Future<String> prepareEntriesDatabase({
  required String destination,
  required Iterable<String> legacyPaths,
}) async {
  final target = File(destination);
  if (await target.exists()) return target.path;

  final candidates = <String>[];
  for (final path in legacyPaths.map(p.canonicalize).toSet()) {
    if (await File(path).exists()) candidates.add(path);
  }
  if (candidates.isEmpty) return target.path;

  await target.parent.create(recursive: true);
  final lock = await File('${target.path}.migration-lock')
      .open(mode: FileMode.append);
  try {
    await lock.lock(FileLock.blockingExclusive);
    if (await target.exists()) return target.path;
    final source = await _selectLegacyDatabase(candidates);
    final staging = await target.parent.createTemp('.entries-migration-');
    final copy = p.join(staging.path, 'entries.db');
    try {
      await _copyDatabase(source, copy);
      final verified = await openReadOnlyDatabase(copy, singleInstance: false);
      try {
        final result = await verified.rawQuery('PRAGMA quick_check');
        if (result.length != 1 || result.single.values.single != 'ok') {
          throw StateError(
            'The migrated notes database did not pass SQLite validation.',
          );
        }
      } finally {
        await verified.close();
      }
      await File(copy).rename(target.path);
    } finally {
      if (await File(copy).exists()) await deleteDatabase(copy);
      await staging.delete();
    }
    return target.path;
  } finally {
    await lock.close();
  }
}

Future<String> _selectLegacyDatabase(List<String> candidates) async {
  if (candidates.length == 1) return candidates.single;
  final populated = <String>[];
  for (final path in candidates) {
    final database = await openReadOnlyDatabase(path, singleInstance: false);
    try {
      final rows = await database.rawQuery(
        'SELECT EXISTS(SELECT 1 FROM entries) OR '
        'EXISTS(SELECT 1 FROM categories WHERE is_default = 0) AS has_data',
      );
      if (rows.single['has_data'] == 1) populated.add(path);
    } finally {
      await database.close();
    }
  }
  if (populated.length > 1) {
    throw StateError(
      'Multiple legacy notes databases contain data: ${populated.join(', ')}',
    );
  }
  return populated.singleOrNull ?? candidates.first;
}

Future<void> _copyDatabase(String source, String destination) async {
  final database = await openDatabase(source, singleInstance: false);
  try {
    // Switching modes checkpoints any pending WAL writes. Fail without publishing
    // a copy if another connection prevents a consistent snapshot.
    final mode = await database.rawQuery('PRAGMA journal_mode = DELETE');
    if (mode.single.values.single.toString().toLowerCase() != 'delete') {
      throw StateError(
        'Close the previous version before migrating its notes database.',
      );
    }
    await database.transaction((transaction) async {
      await File(source).copy(destination);
    }, exclusive: true);
  } finally {
    await database.close();
  }
}
