import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/security/private_content_store.dart';
import '../../profile/data/profile_store.dart';
import '../data/guest_workspace_transfer.dart';
import '../data/datasources/desktop_google_account.dart';
import '../data/datasources/drive_workspace_store.dart';
import '../data/datasources/google_account_remote_datasource.dart';
import '../data/local_workspace_snapshot.dart';
import '../data/workspace_sync.dart';

class CloudSyncController extends ChangeNotifier {
  CloudSyncController(
    this._database, {
    required bool testWorkspace,
    String? testWorkspaceName,
  }) : _privateNamespace = testWorkspaceName,
       _baseKey = testWorkspace
           ? 'entries_test_drive_v1_${testWorkspaceName ?? 'default'}'
           : 'entries_drive_v1' {
    _drive = DriveWorkspaceStore(
      () {
        if (!isConnected) throw StateError('Sign in with Google first.');
        return _google.authorizationHeaders();
      },
      testWorkspace: testWorkspace,
      testWorkspaceName: testWorkspaceName,
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

  final String _baseKey;
  final String? _privateNamespace;
  final DatabaseHelper _database;
  late DatabaseHelper activeDatabase;
  late ProfileStore profile;
  late int _originalUserId;
  late int activeUserId;
  final _retiredProfiles = <ProfileStore>{};
  final workspaceRevision = ValueNotifier<int>(0);
  bool hasGoogleWorkspace = false;
  bool hasCachedGoogleAccounts = false;
  bool guestTransferAvailable = false;
  bool _guestTransferOffered = false;
  bool transferringGuestEntries = false;
  bool get guestTransferOfferPending =>
      guestTransferAvailable && !_guestTransferOffered;
  bool initialSyncPending = false;
  bool _initialSyncRunning = false;
  Timer? _initialEntriesIndicator;
  bool get loadingInitialEntries => initialSyncPending || _initialSyncRunning;
  final _signedOutOwners = <String>{};
  String get _signedOutKey => '${_baseKey}_signed_out';

  bool _isAvailableAccount(LocalUserAccount account) =>
      account.isGuest ||
      (account.googleAccountId?.trim().isNotEmpty == true &&
          account.googleEmail?.trim().isNotEmpty == true &&
          !_signedOutOwners.contains(account.googleAccountId));

  Future<List<LocalUserAccount>> localAccounts() async =>
      (await _database.getLocalAccounts()).where(_isAvailableAccount).toList();

  String? _namespaceFor(int userId) => userId == _originalUserId
      ? _privateNamespace
      : [?_privateNamespace, 'account_$userId'].join('_');
  GuestWorkspaceTransfer get _transfer =>
      GuestWorkspaceTransfer(_database, activeDatabase);

  String get _key => _owner != null ? '${_baseKey}_$_owner' : _baseKey;
  final _google = GoogleAccountRemoteDataSource();
  late final DriveWorkspaceStore _drive;
  WorkspaceSync get _sync => WorkspaceSync(
    LocalWorkspaceSnapshot(activeDatabase),
    _drive,
    getApplicationSupportDirectory,
  );

  late final AppLifecycleListener _lifecycle;
  late final Timer _poll;
  final _preferences = SharedPreferencesAsync();
  Timer? _scheduled;
  bool _foreground = true;
  bool _loaded = false;
  bool _workspaceVisible = false;
  bool _profileVisible = false;
  bool _reconnectWhenOnline = false;
  bool needsGoogleAccess = false;
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
  bool get _canSyncHere =>
      hasGoogleWorkspace &&
      _foreground &&
      (_workspaceVisible || _profileVisible) &&
      !_disposed;
  bool get _canAuto => autoSync && _canSyncHere && conflict == null;

  Future<void> load() async {
    final saved = await _database.initActiveUser();
    final accounts = await _database.getLocalAccounts();
    _originalUserId = accounts
        .map((account) => account.id)
        .reduce((first, next) => first < next ? first : next);
    final legacy = await _readPreferences(_baseKey);
    var id = saved;
    if (legacy != null) {
      final owner = legacy['owner'] as String?;
      if (owner != null) {
        id = await _database.migrateLegacyGoogleOwner(owner);
        final key = '${_baseKey}_$owner';
        if (await _preferences.getString(key) == null) {
          await _preferences.setString(key, jsonEncode(legacy));
        }
      }
    }
    _signedOutOwners.addAll(
      await _preferences.getStringList(_signedOutKey) ?? [],
    );
    final migratedAccounts = await localAccounts();
    hasCachedGoogleAccounts = migratedAccounts.any(
      (account) => !account.isGuest,
    );
    final account = migratedAccounts.firstWhere(
      (account) => account.id == id,
      orElse: () => migratedAccounts.firstWhere((account) => account.isGuest),
    );
    await _activate(account, initial: true);
    _loaded = true;
    if (legacy?['owner'] != null) await _preferences.remove(_baseKey);
  }

  Future<Map<String, dynamic>?> _readPreferences(String key) async {
    final stored = await _preferences.getString(key);
    if (stored == null) return null;
    try {
      final decoded = jsonDecode(stored);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> _activate(
    LocalUserAccount account, {
    bool initial = false,
  }) async {
    final database = DatabaseHelper.forUser(_database, account.id);
    final nextProfile = ProfileStore(database);
    Map<String, dynamic>? data;
    var canTransferGuestEntries = false;
    try {
      await nextProfile.load();
      final owner = account.googleAccountId;
      final key = owner == null ? _baseKey : '${_baseKey}_$owner';
      data = await _readPreferences(key);
      if (owner != null) {
        canTransferGuestEntries = await GuestWorkspaceTransfer(
          _database,
          database,
        ).isAvailable();
      }
      await _database.switchUser(account.id);
    } catch (_) {
      nextProfile.dispose();
      rethrow;
    }
    if (!initial) {
      final previous = profile;
      previous.removeListener(workspaceChanged);
      _retiredProfiles.add(previous);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_retiredProfiles.remove(previous)) previous.dispose();
      });
    }
    _scheduled?.cancel();
    _initialEntriesIndicator?.cancel();
    activeUserId = account.id;
    activeDatabase = database;
    profile = nextProfile..addListener(workspaceChanged);
    PrivateContentStore.workspaceNamespace = _namespaceFor(account.id);
    _owner = account.googleAccountId;
    _reconnectWhenOnline = false;
    needsGoogleAccess = false;
    hasGoogleWorkspace = _owner != null;
    _digest = data?['digest'] as String?;
    lastSync = DateTime.tryParse(data?['lastSync'] as String? ?? '');
    autoSync = data?['auto'] != false;
    initialSyncPending = hasGoogleWorkspace && autoSync;
    _initialSyncRunning = false;
    _syncedGeneration = null;
    _localGeneration = 0;
    conflict = null;
    guestTransferAvailable = canTransferGuestEntries;
    _guestTransferOffered = false;
    message = null;
    accountMessage = null;
    if (!initial) {
      _workspaceVisible = false;
      _profileVisible = false;
      workspaceRevision.value++;
    }
  }

  Future<void> connect({Future<void> Function()? beforeSwitch}) =>
      _run(() async {
        if (profile.saving) return;
        final user = await _google.signIn(chooseAccount: true);
        if (user.id.trim().isEmpty || user.email.trim().isEmpty) {
          throw const DriveSyncException(
            'Could not connect your Google account. Try again.',
          );
        }
        final local = await _database.getOrCreateGoogleAccount(
          googleAccountId: user.id,
          email: user.email,
        );
        if (_signedOutOwners.contains(user.id)) {
          await _saveSignedOutOwners({..._signedOutOwners}..remove(user.id));
        }
        hasCachedGoogleAccounts = true;
        await beforeSwitch?.call();
        if (activeUserId != local.id) {
          await _activate(local);
        } else {
          await profile.load();
        }
      }, accountAction: true).whenComplete(() => _scheduleAuto());

  Future<void> selectAccount(LocalUserAccount account) async {
    if (account.id == activeUserId ||
        busy ||
        profile.saving ||
        !_isAvailableAccount(account)) {
      return;
    }
    await _run(() async {
      await _activate(account);
      if (account.isGuest) return;
      _reconnectWhenOnline = true;
    }, accountAction: true);
    _scheduleAuto();
  }

  Future<void> signOut() => _run(() async {
    final owner = _owner;
    if (owner == null || profile.saving) return;
    final guest = (await _database.getLocalAccounts()).firstWhere(
      (account) => account.isGuest,
    );
    if (account == null || account?.id == owner) {
      try {
        await _google.signOut();
      } catch (error) {
        debugPrint('Could not clear the Google session: ${error.runtimeType}');
      }
    }
    await _saveSignedOutOwners({..._signedOutOwners, owner});
    hasCachedGoogleAccounts = (await localAccounts()).any(
      (account) => !account.isGuest,
    );
    await _activate(guest);
  }, accountAction: true);

  Future<void> _saveSignedOutOwners(Set<String> owners) async {
    await _preferences.setStringList(_signedOutKey, owners.toList());
    _signedOutOwners
      ..clear()
      ..addAll(owners);
  }

  Future<bool> _online() async {
    try {
      return (await InternetAddress.lookup('www.googleapis.com')
              .timeout(const Duration(seconds: 3)))
          .isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  Future<bool> _authorize({required bool interactive}) async {
    final owner = _owner;
    if (owner == null) return false;
    try {
      final alreadyConnected = isConnected;
      final restored = alreadyConnected
          ? account
          : await _google.restore(
              expectedId: owner,
              expectedEmail: profile.email,
            );
      if (restored?.id == owner &&
          await _google.ensureDriveAccess(
            expectedId: owner,
            justRestored: !alreadyConnected,
          )) {
        if (profile.email != restored!.email) {
          await _database.getOrCreateGoogleAccount(
            googleAccountId: owner,
            email: restored.email,
          );
          await profile.load();
        }
        return true;
      }
    } on StateError {
      // Google needs to ask for Drive access again.
    } on GoogleSignInException {
      // An expired or missing session can be renewed interactively.
    }
    if (!interactive) return false;
    final user = await _google.signIn(
      expectedId: owner,
      expectedEmail: profile.email,
    );
    await _database.getOrCreateGoogleAccount(
      googleAccountId: user.id,
      email: user.email,
    );
    await profile.load();
    return isConnected;
  }

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

  void setProfileVisible(bool visible) {
    if (_profileVisible == visible) return;
    _profileVisible = visible;
    _scheduleAuto();
  }

  void workspaceChanged() {
    _localGeneration++;
    _scheduleAuto();
  }

  Future<void> syncNow({bool automatic = false}) =>
      _run(() => _syncWorkspace(automatic: automatic));

  Future<void> _syncWorkspace({required bool automatic}) async {
    if (!hasGoogleWorkspace ||
        (automatic && !_canAuto && !(_canSyncHere && _reconnectWhenOnline))) {
      return;
    }
    final initial = initialSyncPending;
    initialSyncPending = false;
    if (initial) {
      _initialSyncRunning = true;
      // Keep slow or unavailable cloud access from holding the empty workspace.
      _initialEntriesIndicator = Timer(const Duration(seconds: 8), () {
        _initialSyncRunning = false;
        _notify();
      });
      _notify();
    }
    try {
      await _syncEntries(automatic: automatic);
    } finally {
      if (initial) {
        _initialEntriesIndicator?.cancel();
        _initialSyncRunning = false;
      }
    }
  }

  Future<void> _syncEntries({required bool automatic}) async {
    if (!isConnected && !await _online()) {
      if (automatic) return;
      throw const DriveSyncException(
        'Check your internet connection and try again.',
      );
    }
    final interactive = !automatic || (_foreground && _reconnectWhenOnline);
    if (interactive) _reconnectWhenOnline = false;
    final bool authorized;
    try {
      authorized = await _authorize(interactive: interactive);
    } on GoogleSignInException {
      needsGoogleAccess = true;
      rethrow;
    }
    needsGoogleAccess = !authorized;
    if (!authorized) return;
    if (automatic && !_canAuto) return;
    final generation = _localGeneration;
    final transferPending = await _transfer.isPending;
    String? confirmedContent;
    final result = await _sync.sync(
      onConfirmed: transferPending
          ? (content) => confirmedContent = content
          : null,
      previousDigest: _digest,
      localKnownUnchanged:
          automatic && generation == _syncedGeneration && !transferPending,
      applyDownload: (apply) async {
        if (automatic && !_canAuto) throw const _DeferredSync();
        if (!automatic &&
            (!_foreground ||
                !(_workspaceVisible ||
                    _profileVisible ||
                    transferringGuestEntries))) {
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
    if (confirmedContent case final snapshot?) {
      await _transfer.finish(snapshot);
    }
    guestTransferAvailable = await _transfer.isAvailable();
    await _drive.removeSuperseded();
    message = switch (result.result) {
      WorkspaceSyncResult.empty => 'There are no entries to sync yet.',
      WorkspaceSyncResult.current => 'Entries are up to date.',
      WorkspaceSyncResult.uploaded => 'Entries uploaded to Google Drive.',
      WorkspaceSyncResult.downloaded => 'Entries downloaded from Google Drive.',
    };
  }

  Future<void> keepBothCopies({PrivateBackupPassword? requestPassword}) =>
      _run(() async {
        final pending = conflict;
        if (pending == null || !_profileVisible || !_foreground) {
          return;
        }
        if (!await _authorize(interactive: true)) {
          needsGoogleAccess = true;
          return;
        }
        needsGoogleAccess = false;
        try {
          String? confirmedContent;
          _digest = await _sync.keepBoth(
            pending,
            requestPassword: requestPassword,
            beforeApply: () {
              if (!_foreground) throw const PrivateMergeCanceled();
              applyingRemote = true;
              _notify();
            },
            onConfirmed: (content) => confirmedContent = content,
          );
          lastSync = DateTime.now().toUtc();
          downloadedCount++;
          conflict = null;
          await _save();
          if (confirmedContent case final snapshot?) {
            await _transfer.finish(snapshot);
          }
          guestTransferAvailable = await _transfer.isAvailable();
          await _drive.removeSuperseded();
          message = 'Both sets of entries are now synced. See Google Drive copies for imported entries.';
        } finally {
          applyingRemote = false;
          _scheduleAuto();
        }
      });

  void scheduleInitialSync() => _scheduleAuto();

  void finishGuestTransferOffer() {
    _guestTransferOffered = true;
    _scheduleAuto();
  }

  Future<bool> guestHasPrivateEntries() => _transfer.hasPrivateEntries;

  Future<String?> transferGuestEntries({
    required GuestPrivatePassword requestPassword,
    required String unlockPrompt,
    required bool skipPrivate,
  }) async {
    String? failure;
    if (busy) return 'Could not move guest entries. Try again.';
    await _run(() async {
      if (!hasGoogleWorkspace || profile.saving) {
        failure = 'Could not move guest entries. Try again.';
        return;
      }
      transferringGuestEntries = true;
      _notify();
      try {
        // Reconcile the target, including any existing private key, before migrating.
        final pending = await _transfer.isPending;
        await _syncWorkspace(automatic: false);
        if (pending) {
          if (await _transfer.isPending) {
            failure = 'Could not move guest entries. Try again.';
          }
          return;
        }
        if (!guestTransferAvailable || !isConnected) {
          failure = 'Could not move guest entries. Try again.';
          return;
        }
        applyingRemote = true;
        _notify();
        final imported = await _transfer.prepare(
          guestNamespace: _namespaceFor(await _database.guestUserId()),
          requestPassword: requestPassword,
          unlockPrompt: unlockPrompt,
          skipPrivate: skipPrivate,
        );
        if (!imported) return;
        guestTransferAvailable = false;
        _localGeneration++;
        downloadedCount++;
        applyingRemote = false;
        await _syncWorkspace(automatic: false);
        if (await _transfer.isPending) {
          failure = 'Could not move guest entries. Try again.';
        }
      } on PrivateMergeCanceled {
        failure = 'Guest transfer canceled.';
      } finally {
        applyingRemote = false;
        transferringGuestEntries = false;
      }
    }, onError: (error) => failure = error);
    return failure;
  }

  void _scheduleAuto() {
    _scheduled?.cancel();
    if (guestTransferOfferPending) return;
    if (!_canAuto && !(_canSyncHere && _reconnectWhenOnline)) return;
    final immediate = !busy && (initialSyncPending || _reconnectWhenOnline);
    _scheduled = Timer(
      immediate ? Duration.zero : const Duration(seconds: 4),
      () {
        if (busy) {
          _scheduleAuto();
        } else {
          unawaited(syncNow(automatic: true));
        }
      },
    );
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
    ValueChanged<String>? onError,
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
    } on PrivateMergeCanceled {
      // Keep the existing conflict and both copies unchanged.
    } on GoogleSignInException catch (error) {
      errorMessage = error.code == GoogleSignInExceptionCode.canceled
          ? 'Google sign-in was canceled.'
          : 'Could not connect your Google account. Try again.';
    } on WorkspaceConflict catch (error) {
      conflict = error;
      errorMessage = error.message;
    } on DriveSyncException catch (error) {
      errorMessage = error.message;
      if (errorMessage ==
              'Google Drive access expired. Reconnect your Google account.' ||
          errorMessage ==
              'Google Drive access is required. Reconnect and allow access.') {
        needsGoogleAccess = true;
      }
    } on TimeoutException {
      errorMessage = 'Google took too long to respond. Try again.';
    } on PrivateRecoveryFailure catch (failure) {
      errorMessage = switch (failure) {
        PrivateRecoveryFailure.noScreenLock =>
          'Set up a screen lock in your phone settings.',
        PrivateRecoveryFailure.missingKey =>
          'Device recovery is not set up for these entries.',
        PrivateRecoveryFailure.unreadableKey =>
          'Could not open the protected key on this device.',
        PrivateRecoveryFailure.setup =>
          'Could not set up system unlock on this device.',
        PrivateRecoveryFailure.prompt =>
          'Could not verify your screen lock. Try again.',
        PrivateRecoveryFailure.busy =>
          'System verification is already in progress.',
      };
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
      if (errorMessage != null) onError?.call(errorMessage);
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
    _initialEntriesIndicator?.cancel();
    _lifecycle.dispose();
    _drive.close();
    _google.close();
    if (_loaded) profile.dispose();
    for (final previous in _retiredProfiles) {
      previous.dispose();
    }
    _retiredProfiles.clear();
    workspaceRevision.dispose();
    super.dispose();
  }
}

class _DeferredSync implements Exception {
  const _DeferredSync();
}
