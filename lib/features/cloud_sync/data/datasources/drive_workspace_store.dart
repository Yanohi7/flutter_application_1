import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/google_drive_config.dart';

typedef DriveRevision = ({String id, List<String> parents, String digest});

class DriveSyncException implements Exception {
  const DriveSyncException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DriveWorkspaceStore {
  DriveWorkspaceStore(
    this._headers, {
    required bool testWorkspace,
    String? testWorkspaceName,
    http.Client? client,
  }) : _name = testWorkspace
           ? (testWorkspaceName == null
                 ? 'entries_test_sync_v1.json'
                 : 'entries_test_sync_v1_$testWorkspaceName.json')
           : 'entries_sync_v1.json',
       _client = client ?? http.Client();

  final Future<Map<String, String>> Function() _headers;
  final http.Client _client;
  final String _name;
  static const _timeout = Duration(seconds: 60);

  Future<List<DriveRevision>> heads() async {
    final revisions = <DriveRevision>[];
    String? pageToken;
    do {
      final uri = Uri.https(
        GoogleDriveConfig.apiHost,
        GoogleDriveConfig.filesPath,
        {
          'spaces': 'appDataFolder',
          'q': "name = '$_name'",
          'fields': 'nextPageToken,files(id,appProperties)',
          'pageSize': '1000',
          'pageToken': ?pageToken,
        },
      );
      final response = await _client
          .get(uri, headers: await _headers())
          .timeout(_timeout);
      _check(response);
      final page = jsonDecode(response.body) as Map<String, dynamic>;
      for (final file in page['files'] as List<dynamic>? ?? const []) {
        final properties = file['appProperties'] as Map<String, dynamic>?;
        final digest = properties?['digest'];
        if (digest is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
          throw const DriveSyncException(
            'An Entries file in Google Drive could not be read.',
          );
        }
        revisions.add((
          id: file['id'] as String,
          parents: [
            for (final entry in properties!.entries)
              if (entry.key.startsWith('parent')) entry.value as String,
          ],
          digest: digest,
        ));
      }
      pageToken = page['nextPageToken'] as String?;
    } while (pageToken != null);
    final parents = {for (final revision in revisions) ...revision.parents};
    return revisions
        .where((revision) => !parents.contains(revision.id))
        .toList();
  }

  Future<Uint8List> download(String id) async {
    final uri = Uri.https(
      GoogleDriveConfig.apiHost,
      '${GoogleDriveConfig.filesPath}/$id',
      {'alt': 'media'},
    );
    final response = await _client
        .get(uri, headers: await _headers())
        .timeout(_timeout);
    _check(response);
    return response.bodyBytes;
  }

  Future<void> publish(
    Uint8List bytes, {
    required String digest,
    required List<String> parents,
  }) async {
    if (parents.length > 25) {
      throw const DriveSyncException(
        'Too many Drive versions to consolidate safely.',
      );
    }
    final uri = Uri.https(
      GoogleDriveConfig.apiHost,
      GoogleDriveConfig.uploadPath,
      {'uploadType': 'resumable'},
    );
    final response = await _client
        .post(
          uri,
          headers: {
            ...await _headers(),
            'Content-Type': 'application/json; charset=utf-8',
            'X-Upload-Content-Type': 'application/json',
            'X-Upload-Content-Length': bytes.length.toString(),
          },
          body: jsonEncode({
            'name': _name,
            'parents': ['appDataFolder'],
            'mimeType': 'application/json',
            'appProperties': {
              'digest': digest,
              for (final (index, id) in parents.indexed) 'parent$index': id,
            },
          }),
        )
        .timeout(_timeout);
    _check(response);
    final location = Uri.tryParse(response.headers['location'] ?? '');
    if (location == null ||
        location.scheme != 'https' ||
        location.host != GoogleDriveConfig.apiHost ||
        location.path != GoogleDriveConfig.uploadPath) {
      throw const DriveSyncException(
        'Google Drive returned an invalid upload session.',
      );
    }
    final upload = await _client
        .put(
          location,
          headers: {
            'Content-Type': 'application/json',
            'Content-Length': bytes.length.toString(),
          },
          body: bytes,
        )
        .timeout(const Duration(minutes: 3));
    _check(upload);
  }

  void close() => _client.close();

  void _check(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final message = switch (response.statusCode) {
      401 => 'Google Drive access expired. Reconnect your Google account.',
      403 => 'Google Drive denied access. Check the app permissions and Drive API setup.',
      429 ||
      500 ||
      502 ||
      503 ||
      504 => 'Google Drive is temporarily unavailable. Try again.',
      _ =>
        'Google Drive could not complete the request (HTTP ${response.statusCode}).',
    };
    throw DriveSyncException(message);
  }
}
