// Own the recorder and temporary audio files while the entry editor is open

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class EntryAudioInput {
  final recorder = AudioRecorder();
  Directory? _draftDirectory;

  Future<XFile?> pickAudio() async {
    const audioTypes = XTypeGroup(
      label: 'Audio files',
      mimeTypes: ['audio/*'],
      uniformTypeIdentifiers: ['public.audio'],
      extensions: ['m4a', 'mp3', 'wav', 'aac', 'ogg', 'flac', 'opus'],
    );

    return openFile(acceptedTypeGroups: [audioTypes]);
  }

  Future<bool> startRecording() async {
    final isPermissionGranted = await recorder.hasPermission();
    if (!isPermissionGranted) return false;
    final recordingPath = await createRecordingPath();

    await recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: recordingPath,
    );
    return true;
  }

  Future<XFile?> stopRecording() async {
    final String? recordingPath;
    try {
      recordingPath = await recorder.stop();
    } catch (_) {
      try {
        await recorder.cancel();
      } catch (_) {
        // Preserve the original recording error.
      }
      rethrow;
    }
    if (recordingPath == null) return null;
    if (await File(recordingPath).length() == 0) return null;

    return XFile(recordingPath);
  }

  Future<String> createRecordingPath() async {
    final cache = await getTemporaryDirectory();
    final directory = _draftDirectory ??= await cache.createTemp(
      'entry_voice_',
    );
    return path.join(
      directory.path,
      '${DateTime.now().microsecondsSinceEpoch}.m4a',
    );
  }

  Future<void> dispose({
    Future<void> Function(String directory)? beforeCleanup,
  }) async {
    try {
      await recorder.dispose();
    } finally {
      final directory = _draftDirectory;
      if (directory != null && await directory.exists()) {
        await beforeCleanup?.call(directory.path);
        try {
          await directory.delete(recursive: true);
        } on FileSystemException {
          // A media service can briefly keep an open handle after playback.
        }
      }
    }
  }
}
