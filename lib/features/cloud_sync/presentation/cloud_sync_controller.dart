import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/security/private_content_store.dart';
import '../data/datasources/desktop_google_account.dart';
import '../data/datasources/drive_workspace_store.dart';
import '../data/datasources/google_account_remote_datasource.dart';
import '../data/local_workspace_snapshot.dart';
import '../data/workspace_sync.dart';

class CloudSyncController extends ChangeNotifier {
  CloudSyncController(
    DatabaseHelper database, {
    required bool testWorkspace,
    String? testWorkspaceName,
  }) : _key = testWorkspace
           ? 'entries_test_drive_v1_${testWorkspaceName ?? 'default'}'
           : 'entries_drive_v1' {
    _drive = DriveWorkspaceStore(
      _google.authorizationHeaders,
      testWorkspace: testWorkspace,
      testWorkspaceName: testWorkspaceName,
    );
    _sync = WorkspaceSync(
      LocalWorkspaceSnapshot(database),
      _drive,
      getApplicationSupportDirectory,
    );
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _foreground = state == AppLifecycleState.resumed;
        _scheduleAuto();
      },
    );
    _poll = Timer.periodic(const Duration(minutes: 2), (_) => _scheduleAuto());
    PrivateContentStore.passwordRevision.addListener(workspaceChanged);
  }

  final String _key;
  final _google = GoogleAccountRemoteDataSource();
  late final DriveWorkspaceStore _drive;
  late final WorkspaceSync _sync;
  late final AppLifecycleListener _lifecycle;
  late final Timer _poll;
  final _preferences = SharedPreferencesAsync();
  Timer? _scheduled;
  bool _foreground = true;
  bool _workspaceVisible = false;
  bool _profileVisible = false;
  bool _disposed = false;
  String? _owner;
  String? _digest;
  DateTime? lastSync;
  bool autoSync = true;
  bool busy = false;
  bool applyingRemote = false;
  int downloadedCount = 0;
  int _localGeneration = 0;
  int? _syncedGeneration;
  String? message;
  String? accountMessage;
  bool accountBusy = false;
  WorkspaceConflict? conflict;
  WorkspaceGoogleAccount? get account => _google.account;
  bool get isConnected => account != null && account!.id == _owner;
  bool get _canAuto =>
      autoSync &&
      isConnected &&
      _foreground &&
      _workspaceVisible &&
      conflict == null &&
      !_disposed;

  Future<void> load() => _run(() async {
    final stored = await _preferences.getString(_key);
    if (stored != null) {
      final data = jsonDecode(stored) as Map<String, dynamic>;
      _owner = data['owner'] as String?;
      _digest = data['digest'] as String?;
      lastSync = DateTime.tryParse(data['lastSync'] as String? ?? '');
      autoSync = data['auto'] != false;
    }
    if (_owner != null &&
        (await _google.restore())?.id != _owner &&
        account != null) {
      await _google.signOut();
    }
  }).whenComplete(_scheduleAuto);

  Future<void> connect() => _run(() async {
    final user = await _google.signIn();
    if (_owner != null && _owner != user.id) {
      await _google.signOut();
      throw const DriveSyncException(
        'This workspace is linked to another Google account. Reconnect that account.',
      );
    }
    final previousOwner = _owner;
    _owner = user.id;
    try {
      await _save();
    } catch (_) {
      _owner = previousOwner;
      rethrow;
    }
  }, accountAction: true).whenComplete(_scheduleAuto);

  Future<void> disconnect() => _run(() async {
    await _google.signOut();
    _scheduled?.cancel();
    conflict = null;
  }, accountAction: true);

  Future<void> setAutoSync(bool enabled) => _run(() async {
    final previous = autoSync;
    autoSync = enabled;
    try {
      await _save();
    } catch (_) {
      autoSync = previous;
      rethrow;
    }
    _scheduleAuto();
  });

  void setWorkspaceVisible(bool visible) {
    if (_workspaceVisible == visible) return;
    _workspaceVisible = visible;
    _scheduleAuto();
  }

  void setProfileVisible(bool visible) => _profileVisible = visible;

  void workspaceChanged() {
    _localGeneration++;
    _scheduleAuto();
  }

  Future<void> syncNow({bool automatic = false}) => _run(() async {
    if (!isConnected || (automatic && !_canAuto)) return;
    final generation = _localGeneration;
    final result = await _sync.sync(
      previousDigest: _digest,
      localKnownUnchanged: automatic && generation == _syncedGeneration,
      applyDownload: (apply) async {
        if (automatic && !_canAuto) throw const _DeferredSync();
        if (!automatic &&
            (!_foreground || !(_workspaceVisible || _profileVisible))) {
          throw const DriveSyncException(
            'Return to Profile or All Entries and retry the download.',
          );
        }
        applyingRemote = true;
        _notify();
        try {
          await apply();
        } finally {
          applyingRemote = false;
        }
      },
    );
    final oldDigest = _digest;
    final oldTime = lastSync;
    _digest = result.digest;
    lastSync = DateTime.now().toUtc();
    if (result.result == WorkspaceSyncResult.downloaded) downloadedCount++;
    try {
      await _save();
      _syncedGeneration = generation;
    } catch (_) {
      _digest = oldDigest;
      lastSync = oldTime;
      rethrow;
    }
    conflict = null;
    message = switch (result.result) {
      WorkspaceSyncResult.empty => 'There are no entries to sync yet.',
      WorkspaceSyncResult.current => 'Entries are up to date.',
      WorkspaceSyncResult.uploaded => 'Entries uploaded to Google Drive.',
      WorkspaceSyncResult.downloaded => 'Entries downloaded from Google Drive.',
    };
  });

  Future<void> keepBothCopies() => _run(() async {
    final pending = conflict;
    if (pending == null || !isConnected || !_profileVisible || !_foreground) {
      return;
    }
    applyingRemote = true;
    _notify();
    try {
      final digest = await _sync.keepBoth(pending);
      _digest = digest;
      lastSync = DateTime.now().toUtc();
      downloadedCount++;
      conflict = null;
      await _save();
      message = 'Both sets of entries are now synced. See Google Drive copies for imported entries.';
    } finally {
      applyingRemote = false;
      _scheduleAuto();
    }
  });

  void _scheduleAuto() {
    _scheduled?.cancel();
    if (!_canAuto) return;
    _scheduled = Timer(const Duration(seconds: 4), () {
      if (busy) {
        _scheduleAuto();
      } else {
        unawaited(syncNow(automatic: true));
      }
    });
  }

  Future<void> _save() => _preferences.setString(
    _key,
    jsonEncode({
      'owner': _owner,
      'digest': _digest,
      'auto': autoSync,
      'lastSync': lastSync?.toIso8601String(),
    }),
  );

  Future<void> _run(
    Future<void> Function() action, {
    bool accountAction = false,
  }) async {
    if (busy || _disposed) return;
    busy = true;
    accountBusy = accountAction;
    if (accountAction) {
      accountMessage = null;
    } else {
      message = null;
    }
    String? errorMessage;
    _notify();
    try {
      await action();
    } on _DeferredSync {
      _scheduleAuto();
    } on GoogleSignInException catch (error) {
      errorMessage = error.code == GoogleSignInExceptionCode.canceled
          ? 'Google sign-in was canceled.'
          : 'Could not connect your Google account. Try again.';
    } on WorkspaceConflict catch (error) {
      conflict = error;
      errorMessage = error.message;
    } on DriveSyncException catch (error) {
      errorMessage = error.message;
    } on TimeoutException {
      errorMessage = 'Google took too long to respond. Try again.';
    } on http.ClientException {
      errorMessage = 'Check your internet connection and try again.';
    } on StateError catch (error) {
      errorMessage = error.message.toString();
    } catch (error) {
      debugPrint('Entries sync failed: ${error.runtimeType}');
      errorMessage = accountAction
          ? 'Could not connect your Google account. Try again.'
          : 'Could not sync. Your entries are safe on this device.';
    } finally {
      if (accountAction) {
        accountMessage = errorMessage;
      } else if (errorMessage != null) {
        message = errorMessage;
      }
      accountBusy = false;
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    PrivateContentStore.passwordRevision.removeListener(workspaceChanged);
    _scheduled?.cancel();
    _poll.cancel();
    _lifecycle.dispose();
    _drive.close();
    _google.close();
    super.dispose();
  }
}

class _DeferredSync implements Exception {
  const _DeferredSync();
}
