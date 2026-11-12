// Copy entry attachments into app storage and clean up copies owned by the app

import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';

import 'photo_compression.dart';
import 'entry_file_input.dart';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/media_attachment.dart';

class EntryPhotoStorage {
  const EntryPhotoStorage();

  Future<Directory> _root(String fileType) async => Directory(
    path.join(
      (await getApplicationSupportDirectory()).path,
      'entry_${fileType}s',
    ),
  );

  Future<MediaAttachment> copyAttachment(
    String sourcePath,
    String name, {
    required String fileType,
  }) async {
    if (fileType == 'document' || fileType == 'video') {
      await EntryFileInput.validate(sourcePath, name);
    }
    final root = await _root(fileType);
    await root.create(recursive: true);
    final folder = await root.createTemp('${fileType}_');
    final destination = path.join(
      folder.path,
      'attachment${path.extension(name).toLowerCase()}',
    );
    try {
      final file = fileType == 'photo'
          ? File(await compute(compressEntryPhoto, (sourcePath, destination)))
          : await File(sourcePath).copy(destination);
      return MediaAttachment(
        fileType: fileType,
        fileName: path.setExtension(name, path.extension(file.path)),
        localPath: file.path,
        mimeType: lookupMimeType(file.path) ?? 'application/octet-stream',
        fileSize: await file.length(),
      );
    } catch (_) {
      await removeAttachment(destination, fileType: fileType);
      rethrow;
    }
  }

  Future<void> removeAttachment(
    String filePath, {
    required String fileType,
  }) async {
    try {
      final root = await _root(fileType);
      final normalized = path.normalize(filePath);
      final folder = path.dirname(normalized);
      // Only remove copies inside the matching attachment directory
      if (!path.equals(path.dirname(folder), root.path) ||
          !path.basename(folder).startsWith('${fileType}_')) {
        return;
      }
      final file = File(normalized);
      if (await file.exists()) await file.delete();
      final directory = Directory(folder);
      if (await directory.exists() && await directory.list().isEmpty) {
        await directory.delete();
      }
    } on Exception catch (error, stackTrace) {
      developer.log(
        'Could not clean up an entry attachment.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
