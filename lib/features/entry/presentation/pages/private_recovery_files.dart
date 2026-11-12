import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

abstract final class PrivateRecoveryFiles {
  static const _fileName = 'EntryNote-recovery.entrynotekey';
  static const _mimeType = 'application/octet-stream';
  static bool get canShare =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows;

  static Future<Uint8List?> pick() async {
    try {
      final file = await FilePicker.pickFile(dialogTitle: 'Open recovery file');
      if (file == null) return null;
      final length = await file.length();
      if (length != null && length > 4096) {
        throw const FormatException('Choose an EntryNote recovery file.');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in file.readAsByteStream()) {
        if (bytes.length + chunk.length > 4096) {
          throw const FormatException('Choose an EntryNote recovery file.');
        }
        bytes.add(chunk);
      }
      return bytes.takeBytes();
    } finally {
      await _clearTemporaryFiles();
    }
  }

  static Future<bool> save(Uint8List bytes) async {
    try {
      return await FilePicker.saveFile(
            fileName: _fileName,
            bytes: bytes,
            mimeType: _mimeType,
            dialogTitle: 'Save EntryNote recovery file',
          ) !=
          null;
    } finally {
      if (Platform.isIOS) await _clearTemporaryFiles();
    }
  }

  static Future<void> _clearTemporaryFiles() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await FilePicker.clearTemporaryFiles();
    } on Exception {
      // The app-private temporary files can also be purged by the OS.
    }
  }

  static Future<bool> share(Uint8List bytes, Rect origin) async {
    final temp = await (await getTemporaryDirectory()).createTemp(
      'entrynote-key-',
    );
    try {
      final file = File.fromUri(temp.uri.resolve(_fileName));
      await file.writeAsBytes(bytes, flush: true);
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: _mimeType)],
          sharePositionOrigin: origin,
        ),
      );
      return result.status == ShareResultStatus.success;
    } finally {
      try {
        await File.fromUri(temp.uri.resolve(_fileName)).delete();
        await temp.delete();
      } on FileSystemException {
        // The OS may hold the temporary file until its share sheet closes.
      }
    }
  }
}
