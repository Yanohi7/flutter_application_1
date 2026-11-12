import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../../../core/security/private_content_store.dart';
import 'datasources/drive_workspace_store.dart';
import 'local_workspace_snapshot.dart';
import 'workspace_merge.dart';

enum WorkspaceSyncResult { empty, current, uploaded, downloaded }

class WorkspaceConflict extends DriveSyncException {
  const WorkspaceConflict(this.localDigest, this.heads)
    : super(
        'This device and Google Drive have different versions. Both copies were kept.',
      );

  final String localDigest;
  final List<DriveRevision> heads;
}

class WorkspaceSync {
  const WorkspaceSync(this._local, this._drive, this._storageRoot);

  final LocalWorkspaceSnapshot _local;
  final DriveWorkspaceStore _drive;
  final Future<Directory> Function() _storageRoot;

  Future<({WorkspaceSyncResult result, String? digest})> sync({
    String? previousDigest,
    bool localKnownUnchanged = false,
    required Future<void> Function(Future<void> Function()) applyDownload,
  }) async {
    final heads = await _drive.heads();
    final multipleVersions =
        heads.isNotEmpty &&
        heads.any((head) => head.digest != heads.first.digest);
    final remote = heads.firstOrNull;
    if (!multipleVersions &&
        localKnownUnchanged &&
        previousDigest != null &&
        remote?.digest == previousDigest) {
      return (result: WorkspaceSyncResult.current, digest: previousDigest);
    }
    final local = await _local.exportForSync();
    if (remote == null && previousDigest == null && local.isEmpty) {
      return (result: WorkspaceSyncResult.empty, digest: null);
    }
    final key = await _keyFor(local.hasPrivate);
    final (bytes: body, :digest) = await _prepareUpload(local.content, key);
    if (multipleVersions) throw WorkspaceConflict(digest, heads);
    if (remote?.digest == digest) {
      return (result: WorkspaceSyncResult.current, digest: digest);
    }
    if (remote == null || remote.digest == previousDigest) {
      if (remote == null && previousDigest != null) {
        throw const DriveSyncException(
          'The previous Drive backup is missing. Your local entries are still on this device.',
        );
      }
      await _drive.publish(
        body,
        digest: digest,
        parents: heads.map((head) => head.id).toList(),
      );
      return (result: WorkspaceSyncResult.uploaded, digest: digest);
    }
    if (digest != previousDigest && !local.isEmpty) {
      throw WorkspaceConflict(digest, heads);
    }
    final (:content, :envelope, :hasPrivate) = await _download(
      remote,
      'The Google Drive backup did not pass verification.',
    );
    await applyDownload(() async {
      if (hasPrivate) {
        if (envelope == null) {
          throw const DriveSyncException(
            'The backup is missing its protected private information key.',
          );
        }
        await PrivateContentStore.acceptSyncPasswordEnvelope(envelope);
      }
      await _local.restore(
        content,
        storageRoot: await _storageRoot(),
        replaceExpected: local.content,
      );
    });
    return (result: WorkspaceSyncResult.downloaded, digest: remote.digest);
  }

  Future<String> keepBoth(WorkspaceConflict conflict) async {
    final local = await _local.exportForSync();
    final localEnvelope = await _keyFor(local.hasPrivate);
    final localDigest = (await _prepareUpload(
      local.content,
      localEnvelope,
    )).digest;
    final heads = await _drive.heads();
    if (localDigest != conflict.localDigest ||
        heads.length != conflict.heads.length ||
        !heads.every(
          (head) => conflict.heads.any(
            (seen) => seen.id == head.id && seen.digest == head.digest,
          ),
        )) {
      throw const DriveSyncException(
        'A version changed. Run Sync now to review the latest copies.',
      );
    }
    var envelope = localEnvelope;
    final seen = {localDigest};
    final remoteCopies = <String>[];
    for (final head in heads) {
      if (!seen.add(head.digest)) continue;
      final (content: content, envelope: remoteEnvelope, :hasPrivate) =
          await _download(head, 'A Drive copy did not pass verification.');
      if (hasPrivate) {
        if (remoteEnvelope == null ||
            (envelope != null && !_samePrivateKey(envelope, remoteEnvelope))) {
          throw const DriveSyncException(
            'The private information on these copies uses different keys. Both copies are still available.',
          );
        }
        envelope ??= remoteEnvelope;
      }
      remoteCopies.add(content);
    }

    final size = remoteCopies.fold(
      local.content.length,
      (sum, copy) => sum + copy.length,
    );
    final merged = size >= _backgroundThreshold
        ? await compute(_mergeCopies, (local.content, remoteCopies))
        : mergeWorkspaceCopies(local.content, remoteCopies);
    if (localEnvelope == null && envelope != null) {
      await PrivateContentStore.acceptSyncPasswordEnvelope(envelope);
    }
    final (bytes: body, :digest) = await _prepareUpload(merged, envelope);
    await _drive.publish(
      body,
      digest: digest,
      parents: heads.map((head) => head.id).toList(),
    );
    await _local.restore(
      merged,
      storageRoot: await _storageRoot(),
      replaceExpected: local.content,
    );
    return digest;
  }

  bool _samePrivateKey(String first, String second) {
    if (first == second) return true;
    final firstId = (jsonDecode(first) as Map<String, dynamic>)['keyId'];
    final secondId = (jsonDecode(second) as Map<String, dynamic>)['keyId'];
    return firstId is String && firstId == secondId;
  }

  Future<String?> _keyFor(bool hasPrivate) async {
    if (!hasPrivate) return null;
    final key = await PrivateContentStore.readSyncPasswordEnvelope();
    if (key == null) {
      throw const DriveSyncException(
        'Set a private information password before syncing private entries.',
      );
    }
    return key;
  }

  Future<_DriveBackup> _download(DriveRevision revision, String failure) async {
    final bytes = await _drive.download(revision.id);
    final input = (
      bytes: bytes,
      expectedDigest: revision.digest,
      failure: failure,
    );
    return bytes.length >= _backgroundThreshold
        ? compute(_decodeBackup, input)
        : _decodeBackup(input);
  }
}

const _backgroundThreshold = 256 * 1024;
typedef _DriveBackup = ({String content, String? envelope, bool hasPrivate});

Future<({Uint8List bytes, String digest})> _prepareUpload(
  String content,
  String? envelope,
) => content.length >= _backgroundThreshold
    ? compute(_encodeBackup, (content, envelope))
    : _encodeBackup((content, envelope));

Future<({Uint8List bytes, String digest})> _encodeBackup(
  (String, String?) input,
) async {
  final (content, envelope) = input;
  final bytes = utf8.encode(
    jsonEncode({'workspace': content, 'passwordEnvelope': ?envelope}),
  );
  return (bytes: bytes, digest: await _digest(bytes));
}

Future<_DriveBackup> _decodeBackup(
  ({Uint8List bytes, String expectedDigest, String failure}) input,
) async {
  if (await _digest(input.bytes) != input.expectedDigest) {
    throw DriveSyncException(input.failure);
  }
  final document = jsonDecode(utf8.decode(input.bytes)) as Map<String, dynamic>;
  final content = document['workspace'] as String;
  final workspace = jsonDecode(content) as Map<String, dynamic>;
  return (
    content: content,
    envelope: document['passwordEnvelope'] as String?,
    hasPrivate: (workspace['entries'] as List).any(
      (entry) => entry['private_content'] != '',
    ),
  );
}

String _mergeCopies((String, List<String>) input) =>
    mergeWorkspaceCopies(input.$1, input.$2);

Future<String> _digest(Uint8List bytes) async =>
    (await Sha256().hash(bytes)).bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
