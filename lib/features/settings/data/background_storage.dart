import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class BackgroundStorage {
  static Future<Directory> _root() async => Directory(
    path.join((await getApplicationSupportDirectory()).path, 'backgrounds'),
  );

  static Future<String?> pick() async {
    final selected = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Background photos',
          extensions: ['jpg', 'jpeg', 'png', 'webp'],
          mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
        ),
      ],
    );
    if (selected == null) return null;
    if (await selected.length() > 20 * 1024 * 1024)
      throw const FormatException('Choose an image smaller than 20 MB.');
    final bytes = await selected.readAsBytes();
    final descriptor = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final image = await ui.ImageDescriptor.encoded(descriptor);
      try {
        if (image.width > 16000 || image.height > 16000)
          throw const FormatException(
            'Choose an image up to 16,000 pixels on each side.',
          );
      } finally {
        image.dispose();
      }
    } catch (_) {
      throw const FormatException(
        'This image could not be opened. Choose a JPG, PNG or WebP image.',
      );
    } finally {
      descriptor.dispose();
    }
    final root = await _root();
    await root.create(recursive: true);
    final folder = await root.createTemp('photo_');
    final destination = path.join(
      folder.path,
      'background${path.extension(selected.name).toLowerCase()}',
    );
    try {
      await File(destination).writeAsBytes(bytes, flush: true);
      return destination;
    } catch (_) {
      if (await folder.list().isEmpty) await folder.delete();
      rethrow;
    }
  }

  static Future<void> remove(String? filePath) async {
    if (filePath == null) return;
    try {
      final root = path.normalize((await _root()).absolute.path);
      final target = path.normalize(File(filePath).absolute.path);
      // Only clean up copies owned by this feature, never the selected source file.
      if (!path.isWithin(root, target)) return;
      final file = File(target);
      if (await file.exists()) await file.delete();
      final folder = file.parent;
      if (!path.equals(folder.path, root) &&
          await folder.exists() &&
          await folder.list().isEmpty)
        await folder.delete();
    } on FileSystemException catch (error) {
      debugPrint('Could not remove an unused background copy: $error');
    }
  }
}
