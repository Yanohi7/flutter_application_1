// Pick supported documents and hand them to the operating system without executing shell commands

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

class EntryFileInput {
  static const _androidPicker = MethodChannel('entries/attachment_picker');
  static const maxBytes = 10 * 1024 * 1024;
  static const videoExtensions = ['mp4', 'm4v', 'mov', 'webm'];
  static const extensions = [
    'pdf',
    'txt',
    'md',
    'rtf',
    'doc',
    'docx',
    'odt',
    'csv',
    'xls',
    'xlsx',
    'zip',
    ...videoExtensions,
  ];
  static const mimeTypes = [
    'application/pdf',
    'text/plain',
    'text/markdown',
    'application/rtf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.oasis.opendocument.text',
    'text/csv',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/zip',
    'video/mp4',
    'video/x-m4v',
    'video/quicktime',
    'video/webm',
  ];

  static Future<({List<XFile> files, bool skipped, bool unreadable})>
  pick() async {
    if (!Platform.isAndroid) {
      final files = await openFiles(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Documents, archives and video',
            extensions: extensions,
            mimeTypes: mimeTypes,
            uniformTypeIdentifiers: ['public.data'],
          ),
        ],
      );
      return (files: files, skipped: false, unreadable: false);
    }

    final selected = await _androidPicker
        .invokeListMethod<Map<Object?, Object?>>('pick', {
          'extensions': extensions,
          'mimeTypes': mimeTypes,
          'maxBytes': maxBytes,
        });
    final files = <XFile>[];
    var skipped = false;
    var unreadable = false;
    for (final item in selected ?? const <Map<Object?, Object?>>[]) {
      final filePath = item['path'];
      final name = item['name'];
      if (filePath is String && name is String) {
        files.add(_PickedAndroidFile(filePath, name));
      } else if (item['status'] == 'skipped') {
        skipped = true;
      } else {
        unreadable = true;
      }
    }
    return (files: files, skipped: skipped, unreadable: unreadable);
  }

  static Future<void> discardPickedFile(String filePath) async {
    if (!Platform.isAndroid) return;
    if (!path.basename(filePath).startsWith('entry-attachment-')) return;
    try {
      await File(filePath).delete();
    } on FileSystemException {
      // The temporary file may already have been removed.
    }
  }

  static String attachmentType(String name) =>
      videoExtensions.contains(
        path.extension(name).toLowerCase().replaceFirst('.', ''),
      )
      ? 'video'
      : 'document';

  static Future<void> validate(String filePath, String name) async {
    if (!extensions.contains(
      path.extension(name).toLowerCase().replaceFirst('.', ''),
    )) {
      throw const FormatException('This file format is not supported.');
    }
    if (await File(filePath).length() > maxBytes) {
      throw const FormatException('Each file must be 10 MB or smaller.');
    }
  }

  static Future<void> open(String filePath) async {
    await validate(filePath, filePath);
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      if (!await launchUrl(
        Uri.file(filePath),
        mode: LaunchMode.externalApplication,
      )) {
        throw const FormatException(
          'No application could open this file. Install a compatible viewer.',
        );
      }
      return;
    }
    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done) {
      throw const FormatException(
        'Could not open this file. Check that a compatible viewer is installed.',
      );
    }
  }
}

class _PickedAndroidFile extends XFile {
  _PickedAndroidFile(super.path, this.name);

  @override
  final String name;
}
