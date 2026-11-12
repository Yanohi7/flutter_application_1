import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'workspace_samples.dart';

/// Populate a fresh SQLite database for tests.
Future<void> populateTestDatabase(
  Database database, {
  required Directory mediaDirectory,
  required Uint8List photo,
  String privateContent = '',
  DateTime? now,
}) async {
  await mediaDirectory.create(recursive: true);
  final files = [
    ('photo', 'workspace.jpg', 'Workspace inspiration', 'image/jpeg', photo),
    ('audio', 'sound-check.wav', 'Sound check', 'audio/wav', _sampleAudio()),
    (
      'document',
      'review-notes.txt',
      'Review notes',
      'text/plain',
      utf8.encode('Entries review\nCheck the category, note and attachment.\n'),
    ),
  ];
  for (final (_, name, _, _, bytes) in files) {
    await File(p.join(mediaDirectory.path, name))
        .writeAsBytes(bytes, flush: true);
  }
  await database.transaction((txn) async {
    if ((await txn.query('users', columns: ['id'], limit: 1)).isNotEmpty) {
      return;
    }
    await _insertWorkspace(
      txn,
      mediaDirectory,
      files,
      now ?? DateTime.now(),
      privateContent,
    );
  });
}

Future<void> _insertWorkspace(
  Transaction database,
  Directory mediaDirectory,
  List<(String, String, String, String, List<int>)> files,
  DateTime today,
  String privateContent,
) async {
  final createdAt = today.toIso8601String();
  final userId = await database.insert('users', {'created_at': createdAt});
  await database.insert('profiles', {
    'user_id': userId,
    'display_name': 'Alex Morgan',
    'avatar_image': _sampleAvatar(),
    'created_at': createdAt,
  });

  var categoryOrder = 0;
  var entryOrder = 0;

  Future<int> addCategory(
    String name, {
    int? parentId,
    bool isDefault = false,
  }) => database.insert('categories', {
    'user_id': userId,
    'name': name,
    'parent_id': parentId,
    'is_default': isDefault ? 1 : 0,
    'is_system': isDefault ? 1 : 0,
    'sort_order': categoryOrder++,
    'created_at': createdAt,
    'updated_at': createdAt,
  });

  Future<void> addEntry(
    int categoryId,
    SampleEntry entry, {
    bool featured = false,
    List<int> attachments = const [],
  }) async {
    const daysAgo = [0, 1, 4, 14, 60];
    final index = entryOrder++;
    final date = today.subtract(
      Duration(days: daysAgo[index % daysAgo.length], minutes: index),
    );
    final entryId = await database.insert('entries', {
      'category_id': categoryId,
      'title': entry.title,
      'content': entry.content,
      if (featured) 'private_content': privateContent,
      'created_at': date.toIso8601String(),
      'updated_at': date.toIso8601String(),
      'is_pinned': featured || index == 3 || index == 29 ? 1 : 0,
      'is_favorite': featured || index % 5 == 0 ? 1 : 0,
    });
    for (final index in attachments) {
      final (type, fileName, label, mime, bytes) = files[index];
      await database.insert('media_attachments', {
        'entry_id': entryId,
        'file_type': type,
        'file_name': fileName,
        'display_name': label,
        'local_path': p.join(mediaDirectory.path, fileName),
        'mime_type': mime,
        'file_size': bytes.length,
        'created_at': date.toIso8601String(),
      });
    }
  }

  Future<void> addBranch(SampleCategory category, {int? parentId}) async {
    final id = await addCategory(category.name, parentId: parentId);
    for (final entry in category.entries) {
      await addEntry(
        id,
        entry,
        attachments: switch (entry.title) {
          'One-page comic idea' => [0],
          'Practice session' => [1],
          'Handoff before lunch' => [2],
          _ => const [],
        },
      );
    }
    for (final child in category.children) {
      await addBranch(child, parentId: id);
    }
  }

  final general = await addCategory('General', isDefault: true);
  await addEntry(
    general,
    SampleEntry(
      'Comic panel study',
      [
        'Try a rooftop scene just after sunset. Use the attached image for the color study, and the audio cue to pace the final panel.',
        checklist('Before drawing', [
          'Choose a skyline reference',
          'Sketch three silhouettes',
          'Block in the light',
        ], checked: 1),
        'The last panel should still make sense without dialogue.',
        table('Layout', [
          ['Panel', 'What the reader sees', 'Status'],
          ['1', 'A wide rooftop view with the city below', 'Sketched'],
          ['2', 'A close-up of the letter under the door', 'Next'],
        ]),
        numbered('Next pass', [
          'Try two crops',
          'Check the shadows',
          'Export a small proof',
        ]),
      ].join('\n'),
    ),
    featured: true,
    attachments: [0, 1, 2],
  );
  for (final category in sampleCategories) {
    await addBranch(category);
  }
}

Uint8List _sampleAvatar() {
  final picture = img.Image(width: 192, height: 192);
  img.fill(picture, color: img.ColorRgb8(38, 70, 83));
  img.fillCircle(
    picture,
    x: 155,
    y: 36,
    radius: 48,
    color: img.ColorRgb8(65, 130, 129),
  );
  img.fillCircle(
    picture,
    x: 96,
    y: 166,
    radius: 52,
    color: img.ColorRgb8(230, 163, 95),
  );
  img.fillCircle(
    picture,
    x: 96,
    y: 78,
    radius: 39,
    color: img.ColorRgb8(34, 34, 48),
  );
  img.fillCircle(
    picture,
    x: 98,
    y: 89,
    radius: 29,
    color: img.ColorRgb8(243, 195, 153),
  );
  img.fillCircle(
    picture,
    x: 88,
    y: 90,
    radius: 3,
    color: img.ColorRgb8(34, 34, 48),
  );
  img.fillCircle(
    picture,
    x: 108,
    y: 90,
    radius: 3,
    color: img.ColorRgb8(34, 34, 48),
  );
  return img.encodePng(picture);
}

Uint8List _sampleAudio() {
  const rate = 16000;
  const samples = rate * 3;
  final bytes = ByteData(44 + samples * 2);
  void ascii(int offset, String text) {
    for (final (index, unit) in text.codeUnits.indexed) {
      bytes.setUint8(offset + index, unit);
    }
  }

  void word(int offset, int value) =>
      bytes.setUint16(offset, value, Endian.little);
  void size(int offset, int value) =>
      bytes.setUint32(offset, value, Endian.little);
  ascii(0, 'RIFF');
  size(4, bytes.lengthInBytes - 8);
  ascii(8, 'WAVEfmt ');
  size(16, 16);
  word(20, 1);
  word(22, 1);
  size(24, rate);
  size(28, rate * 2);
  word(32, 2);
  word(34, 16);
  ascii(36, 'data');
  size(40, samples * 2);
  const notes = [261.63, 329.63, 392.0];
  for (var index = 0; index < samples; index++) {
    final time = (index % rate) / rate;
    final envelope = math.min(time * 12, 1) * math.pow(1 - time, 3);
    final value = math.sin(2 * math.pi * notes[index ~/ rate] * time);
    bytes.setInt16(
      44 + index * 2,
      (value * envelope * 6500).round(),
      Endian.little,
    );
  }
  return bytes.buffer.asUint8List();
}
