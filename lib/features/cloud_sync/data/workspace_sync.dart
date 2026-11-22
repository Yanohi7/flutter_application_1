import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../../../core/security/private_content_store.dart';
import 'datasources/drive_workspace_store.dart';
import 'local_workspace_snapshot.dart';
import 'workspace_merge.dart';

enum WorkspaceSyncResult { empty, current, uploaded, downloaded, merged }

typedef PrivateBackupPassword = Future<String?> Function({
  required bool local,
  required int copy,
});

class PrivateMergeCanceled implements Exception {
  const PrivateMergeCanceled();
}

class PrivateSyncPasswordRequired extends DriveSyncException {
  const PrivateSyncPasswordRequired()
    : super(
        'The private information on these copies uses different passwords.',
      );
}

class WorkspaceSync {
  const WorkspaceSync(this._local, this._drive, this._storageRoot);

  final LocalWorkspaceSnapshot _local;
  final DriveWorkspaceStore _drive;
  final Future<Directory> Function() _storageRoot;

  Future<({WorkspaceSyncResult result, String? digest})> sync({
    String? previousDigest,
    bool localKnownUnchanged = false,
    void Function(String)? onConfirmed,
    PrivateBackupPassword? requestPassword,
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
    final key = await _keyFor(local.hasPrivate);
    if (remote == null &&
        previousDigest == null &&
        local.isEmpty &&
        key == null) {
      return (result: WorkspaceSyncResult.empty, digest: null);
    }
    final (bytes: body, :digest) = await _prepareUpload(local.content, key);
    Future<({WorkspaceSyncResult result, String? digest})> merge() async {
      final mergedDigest = await _merge(
        local.content,
        key,
        digest,
        heads,
        onConfirmed: onConfirmed,
        requestPassword: requestPassword,
        applyDownload: applyDownload,
      );
      return (result: WorkspaceSyncResult.merged, digest: mergedDigest);
    }

    if (multipleVersions) return merge();
    if (remote?.digest == digest) {
      onConfirmed?.call(local.content);
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
      onConfirmed?.call(local.content);
      return (result: WorkspaceSyncResult.uploaded, digest: digest);
    }
    if (digest != previousDigest && !local.isEmpty) {
      return merge();
    }
    final (:content, :envelope, :hasPrivate) = await _download(
      remote,
      'The Google Drive backup did not pass verification.',
    );
    final configuredEnvelope =
        await PrivateContentStore.readSyncPasswordEnvelope();
    if (hasPrivate &&
        envelope != null &&
        configuredEnvelope != null &&
        !sameWorkspacePrivateKey(configuredEnvelope, envelope)) {
      return merge();
    }
    await applyDownload(() async {
      if (hasPrivate && envelope == null) {
        throw const DriveSyncException(
          'The backup is missing its protected private information key.',
        );
      }
      await _local.restore(
        content,
        storageRoot: await _storageRoot(),
        replaceExpected: local.content,
        afterRestore:
            envelope != null &&
                (configuredEnvelope == null ||
                    sameWorkspacePrivateKey(configuredEnvelope, envelope))
            ? (txn) => PrivateContentStore.acceptSyncPasswordEnvelope(
                envelope,
                transaction: txn,
              )
            : null,
      );
    });
    return (result: WorkspaceSyncResult.downloaded, digest: remote.digest);
  }

  Future<String> _merge(
    String localContent,
    String? configuredEnvelope,
    String localDigest,
    List<DriveRevision> heads, {
    void Function(String)? onConfirmed,
    PrivateBackupPassword? requestPassword,
    required Future<void> Function(Future<void> Function()) applyDownload,
  }) async {
    var envelope = configuredEnvelope;
    var targetCopy = 0;
    final seen = {localDigest};
    final remoteCopies = <String>[];
    SecretKeyData? targetKey;
    try {
      for (final (index, head) in heads.indexed) {
        if (!seen.add(head.digest)) continue;
        final (content: content, envelope: remoteEnvelope, :hasPrivate) =
            await _download(head, 'A Drive copy did not pass verification.');
        if (envelope == null && remoteEnvelope != null) {
          envelope = remoteEnvelope;
          targetCopy = index + 1;
        }
        if (hasPrivate) {
          if (remoteEnvelope == null) {
            throw const DriveSyncException(
              'The backup is missing its protected private information key.',
            );
          }
          final target = envelope!;
          if (!sameWorkspacePrivateKey(target, remoteEnvelope)) {
            targetKey ??= await _requestKey(
              target,
              requestPassword,
              local: configuredEnvelope != null,
              copy: targetCopy,
            );
            final source = await _requestKey(
              remoteEnvelope,
              requestPassword,
              local: false,
              copy: index + 1,
            );
            try {
              remoteCopies.add(
                await _reencryptPrivateEntries(content, source, targetKey),
              );
            } finally {
              source.destroy();
            }
            continue;
          }
        }
        remoteCopies.add(content);
      }
    } finally {
      targetKey?.destroy();
    }

    final size = remoteCopies.fold(
      localContent.length,
      (sum, copy) => sum + copy.length,
    );
    final merged = size >= _backgroundThreshold
        ? await compute(_mergeCopies, (localContent, remoteCopies))
        : mergeWorkspaceCopies(localContent, remoteCopies);
    final (bytes: body, :digest) = await _prepareUpload(merged, envelope);
    await applyDownload(() async {
      final currentHeads = await _drive.heads();
      if (currentHeads.length != heads.length ||
          !currentHeads.every(
            (head) => heads.any(
              (copy) => head.id == copy.id && head.digest == copy.digest,
            ),
          ) ||
          (await _local.exportForSync()).content != localContent ||
          await PrivateContentStore.readSyncPasswordEnvelope() !=
              configuredEnvelope) {
        throw const DriveSyncException(
          'Entries changed during sync. Try again.',
        );
      }
      await _drive.publish(
        body,
        digest: digest,
        parents: heads.map((head) => head.id).toList(),
      );
      await _local.restore(
        merged,
        storageRoot: await _storageRoot(),
        replaceExpected: localContent,
        afterRestore: configuredEnvelope == null && envelope != null
            ? (txn) => PrivateContentStore.acceptSyncPasswordEnvelope(
                envelope!,
                transaction: txn,
              )
            : null,
      );
    });
    onConfirmed?.call(merged);
    return digest;
  }

  Future<SecretKeyData> _requestKey(
    String envelope,
    PrivateBackupPassword? requestPassword, {
    required bool local,
    required int copy,
  }) async {
    if (requestPassword == null) {
      throw const PrivateSyncPasswordRequired();
    }
    final password = await requestPassword(local: local, copy: copy);
    if (password == null) throw const PrivateMergeCanceled();
    try {
      return await PrivateContentStore.unlockPasswordEnvelope(
        envelope,
        password,
      );
    } on FormatException {
      throw const DriveSyncException('Incorrect private password.');
    }
  }

  Future<String> _reencryptPrivateEntries(
    String content,
    SecretKey source,
    SecretKey target,
  ) async {
    final workspace = jsonDecode(content) as Map<String, dynamic>;
    await reencryptWorkspacePrivateEntries(
      (workspace['entries'] as List).cast<Map<String, dynamic>>(),
      source,
      target,
    );
    return jsonEncode(workspace);
  }

  Future<String?> _keyFor(bool hasPrivate) async {
    final key = await PrivateContentStore.readSyncPasswordEnvelope();
    if (hasPrivate && key == null) {
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
      (entry) => entry['is_deleted'] == 0 && entry['private_content'] != '',
    ),
  );
}

String _mergeCopies((String, List<String>) input) =>
    mergeWorkspaceCopies(input.$1, input.$2);

Future<String> _digest(Uint8List bytes) async =>
    (await Sha256().hash(bytes)).bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
