// Protect private text with a workspace key and independent ways to unlock it.

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';

typedef _PrivateWorkspace = ({
  DatabaseHelper? helper,
  String? namespace,
  int? userId,
});

enum PrivateRecoveryFailure implements Exception {
  noScreenLock,
  missingKey,
  unreadableKey,
  setup,
  prompt,
  busy,
}

class PrivateContentStore {
  static final cipher = AesGcm.with256bits();
  static final passwordRevision = ValueNotifier<int>(0);
  static const minimumPasswordLength = 6;
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
    // New private fields have no legacy Windows storage to migrate
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );
  static String? workspaceNamespace;
  static DatabaseHelper? database;
  static const _passwordStorageKey = 'entries_private_password_v1';
  static String _workspaceKey(String key) =>
      workspaceNamespace == null ? key : '${key}_$workspaceNamespace';
  static String get _biometricNamespace =>
      _workspaceKey('entries_private_biometric_namespace_v1');
  static final _context = utf8.encode('entries.private-content.v1');
  static const _channel = MethodChannel('entries/privacy');
  static const _cryptoChannel = MethodChannel('entries/private_crypto');
  static final _passwordContext = utf8.encode('entries.password-key.v1');
  static const _androidBiometricPrefix = 'entries_android_biometric_';

  static Future<void> protectScreen(bool value) async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('protectScreen', value);
    }
  }

  static Future<bool> hasPassword() async =>
      await readSyncPasswordEnvelope() != null;

  static Future<String?> readSyncPasswordEnvelope({
    DatabaseExecutor? transaction,
  }) async {
    final scope = await _captureWorkspace();
    return readPasswordEnvelopeForWorkspace(
      scope.namespace,
      userId: scope.userId,
      transaction: transaction,
    );
  }

  static Future<_PrivateWorkspace> _captureWorkspace() async {
    final helper = database;
    final namespace = workspaceNamespace;
    return (
      helper: helper,
      namespace: namespace,
      userId: await helper?.workspaceUserId(),
    );
  }

  static Future<String?> readPasswordEnvelopeForWorkspace(
    String? namespace, {
    int? userId,
    DatabaseExecutor? transaction,
  }) async {
    final db = transaction ?? await database?.database;
    if (db != null && userId != null) {
      final rows = await db.query(
        'private_workspace_keys',
        columns: ['envelope'],
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      if (rows.isNotEmpty) return rows.single['envelope'] as String;
    }
    return _storage.read(key: _keyForWorkspace(_passwordStorageKey, namespace));
  }

  static String _keyForWorkspace(String key, String? namespace) =>
      namespace == null ? key : '${key}_$namespace';

  static Future<void> writeWorkspaceEnvelope(
    DatabaseExecutor db,
    int userId,
    String envelope,
  ) => db.insert('private_workspace_keys', {
    'user_id': userId,
    'envelope': envelope,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<void> _saveEnvelope(
    String envelope, {
    required _PrivateWorkspace scope,
    DatabaseExecutor? transaction,
  }) async {
    final (:helper, :namespace, :userId) = scope;
    if (helper == null || userId == null) {
      await _storage.write(
        key: _keyForWorkspace(_passwordStorageKey, namespace),
        value: envelope,
      );
    } else {
      await writeWorkspaceEnvelope(
        transaction ?? await helper.database,
        userId,
        envelope,
      );
    }
  }

  static Future<void> acceptSyncPasswordEnvelope(
    String envelope, {
    DatabaseExecutor? transaction,
  }) async {
    final scope = await _captureWorkspace();
    final current = await readPasswordEnvelopeForWorkspace(
      scope.namespace,
      userId: scope.userId,
      transaction: transaction,
    );
    if (current == envelope) return;
    final parsed = jsonDecode(envelope);
    if (parsed is! Map ||
        parsed['v'] != 1 ||
        !['s', 'n', 'c', 'm'].every((key) => parsed[key] is String)) {
      throw const FormatException('Invalid private information key.');
    }
    if (current != null) {
      final local = jsonDecode(current) as Map<String, dynamic>;
      final keyId = parsed['keyId'];
      final sameKey = keyId is String && keyId == local['keyId'];
      final legacyId = local['keyId'] == null
          ? await _fingerprint(utf8.encode(current))
          : null;
      if (!sameKey && (legacyId == null || legacyId != parsed['legacyId'])) {
        throw StateError(
          'This device uses a different private information key.',
        );
      }
    } else if (await hasBiometrics()) {
      throw StateError('This device uses a different private information key.');
    }
    await _saveEnvelope(envelope, scope: scope, transaction: transaction);
  }

  static bool get supportsBiometrics => Platform.isAndroid || Platform.isIOS;

  static Future<bool> canOfferBiometrics() async {
    if (!supportsBiometrics) return false;
    try {
      return await _channel.invokeMethod<bool>('canOfferBiometrics') == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> hasBiometrics() async =>
      supportsBiometrics &&
      await _storage.containsKey(key: _biometricNamespace);

  static Future<bool> hasDeviceRecovery({
    String? namespace,
    int? userId,
  }) async {
    if (!supportsBiometrics) return false;
    final scope = userId == null ? workspaceNamespace : namespace;
    final envelope = userId == null
        ? await readSyncPasswordEnvelope()
        : await readPasswordEnvelopeForWorkspace(scope, userId: userId);
    final alias = _systemRecoveryAlias(scope, envelope);
    return (alias != null && await _storage.containsKey(key: alias)) ||
        await _storage.containsKey(
          key: _keyForWorkspace('entries_recovery_v2', scope),
        ) ||
        await _storage.containsKey(
          key: _keyForWorkspace('entries_recovery_v1', scope),
        ) ||
        await _deferredStorage.containsKey(
          key: _keyForWorkspace('entries_screen_lock_v1', scope),
        );
  }

  static String? _systemRecoveryAlias(String? namespace, String? envelope) {
    if (envelope == null) return null;
    final keyId = (jsonDecode(envelope) as Map<String, dynamic>)['keyId'];
    return keyId is String
        ? _keyForWorkspace(
            'entries_recovery_v3_${keyId.replaceAll('=', '')}',
            namespace,
          )
        : null;
  }

  static FlutterSecureStorage get _deferredStorage => Platform.isIOS
      ? const FlutterSecureStorage(
          iOptions: IOSOptions(
            accountName: 'entrynote.screen-lock',
            accessibility: KeychainAccessibility.unlocked_this_device,
          ),
        )
      : _storage;

  static Future<bool> hasScreenLock() async =>
      supportsBiometrics &&
      await _channel.invokeMethod<bool>('hasScreenLock') == true;

  static Future<void> openScreenLockSettings() async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('openScreenLockSettings');
    }
  }

  static FlutterSecureStorage _iosDeviceRecovery(
    String account, {
    bool passcodeOnly = false,
  }) => FlutterSecureStorage(
    iOptions: IOSOptions(
      accountName: account,
      accessibility: KeychainAccessibility.passcode,
      accessControlFlags: [
        passcodeOnly
            ? AccessControlFlag.devicePasscode
            : AccessControlFlag.userPresence,
      ],
      label: 'EntryNote password recovery',
    ),
  );

  /// Store a device-bound copy only after a screen lock is configured.
  static Future<void> prepareDeviceRecovery(SecretKey key) =>
      prepareWorkspaceDeviceRecovery(key, workspaceNamespace);

  static Future<void> prepareWorkspaceDeviceRecovery(
    SecretKey key,
    String? scope,
  ) async {
    if (!supportsBiometrics) return;
    if (!await hasScreenLock()) {
      throw PrivateRecoveryFailure.noScreenLock;
    }
    final bytes = Uint8List.fromList(await key.extractBytes());
    final keyId = (await _fingerprint(bytes)).replaceAll('=', '');
    final alias = _keyForWorkspace('entries_recovery_v3_$keyId', scope);
    try {
      final repairFlag = '${alias}_repair';
      final needsRepair = await _storage.containsKey(key: repairFlag);
      if (await _storage.containsKey(key: alias) && !needsRepair) {
        final missing = await _deviceRecoveryCall<bool>(
          'isScreenLockKeyMissing',
          alias,
        );
        if (missing == false) return;
      }
      if (Platform.isAndroid) {
        final wrapped = await _deviceRecoveryCall<Uint8List>(
          'wrapDeviceRecoveryKey',
          {'alias': alias, 'data': bytes},
        );
        if (wrapped == null) throw PrivateRecoveryFailure.setup;
        await _storage.write(key: alias, value: base64Encode(wrapped));
      } else {
        await _deviceRecoveryCall<void>('wrapSystemRecoveryKey', {
          'alias': alias,
          'data': bytes,
          if (needsRepair) 'replace': true,
        });
        await _storage.write(key: alias, value: '1');
      }
      await _storage.delete(key: repairFlag);
      await _removeDeferredScreenLock(scope);
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  static Future<void> _removeDeferredScreenLock(String? scope) async {
    try {
      await _deferredStorage.delete(
        key: _keyForWorkspace('entries_screen_lock_v1', scope),
      );
      if (Platform.isAndroid) {
        await _channel.invokeMethod<void>(
          'deleteDeferredScreenLockKey',
          _keyForWorkspace('entries_recovery_v1', scope),
        );
      }
    } catch (_) {
      // The new credential-bound copy has already been committed.
    }
  }

  static Future<SecretKeyData?> unlockWithDeviceRecovery({
    required String prompt,
    String? namespace,
    int? userId,
  }) async {
    if (!supportsBiometrics) return null;
    final scope = userId == null ? workspaceNamespace : namespace;
    final envelope = userId == null
        ? await readSyncPasswordEnvelope()
        : await readPasswordEnvelopeForWorkspace(scope, userId: userId);
    if (envelope == null) throw PrivateRecoveryFailure.missingKey;
    final systemAlias = _systemRecoveryAlias(scope, envelope);
    final systemCopy = systemAlias == null
        ? null
        : await _storage.read(key: systemAlias);
    if (systemCopy != null) {
      final alias = systemAlias!;
      try {
        final bytes = Platform.isAndroid
            ? await _deviceRecoveryCall<Uint8List>('unwrapDeviceRecoveryKey', {
                'alias': alias,
                'data': base64Decode(systemCopy),
                'prompt': prompt,
              })
            : await _deviceRecoveryCall<Uint8List>('unwrapSystemRecoveryKey', {
                'alias': alias,
                'prompt': prompt,
              });
        return await _verifiedRecoveryKey(bytes, envelope);
      } on FormatException {
        await _markRecoveryForRepair(alias);
        throw PrivateRecoveryFailure.missingKey;
      } on PrivateRecoveryFailure catch (failure) {
        if (failure == PrivateRecoveryFailure.missingKey) {
          await _markRecoveryForRepair(alias);
        }
        rethrow;
      }
    }
    final passcodeAlias = _keyForWorkspace('entries_recovery_v2', scope);
    final legacyAlias = _keyForWorkspace('entries_recovery_v1', scope);
    final passcodeCopy = await _storage.read(key: passcodeAlias);
    final passcodeOnly = passcodeCopy != null;
    final alias = passcodeOnly ? passcodeAlias : legacyAlias;
    final saved = passcodeCopy ?? await _storage.read(key: legacyAlias);
    Uint8List? bytes;
    if (saved == null) {
      if (Platform.isIOS &&
          await _deviceRecoveryCall<bool>('verifyScreenLock', prompt) != true) {
        return null;
      }
      final deferred = await _deferredStorage.read(
        key: _keyForWorkspace('entries_screen_lock_v1', scope),
      );
      if (deferred == null) {
        throw PrivateRecoveryFailure.missingKey;
      }
      if (Platform.isAndroid) {
        bytes = await _deviceRecoveryCall<Uint8List>(
          'unwrapDeferredScreenLockKey',
          {'alias': alias, 'data': base64Decode(deferred), 'prompt': prompt},
        );
      } else {
        bytes = base64Decode(deferred);
      }
    } else if (Platform.isAndroid) {
      bytes = await _deviceRecoveryCall<Uint8List>('unwrapDeviceRecoveryKey', {
        'alias': alias,
        'data': base64Decode(saved),
        'passcodeOnly': passcodeOnly,
        'prompt': prompt,
      });
    } else {
      try {
        if (!passcodeOnly &&
            await _deviceRecoveryCall<bool>('verifyScreenLock', prompt) !=
                true) {
          return null;
        }
        final encoded = await _iosDeviceRecovery(
          alias,
          passcodeOnly: passcodeOnly,
        ).read(key: 'private_key');
        if (encoded == null) {
          throw PrivateRecoveryFailure.missingKey;
        }
        bytes = base64Decode(encoded);
      } on PlatformException catch (error) {
        debugPrint(
          'Legacy iOS recovery could not read the device key: ${error.code}',
        );
        throw PrivateRecoveryFailure.unreadableKey;
      }
    }
    return _verifiedRecoveryKey(bytes, envelope);
  }

  static Future<SecretKeyData?> _verifiedRecoveryKey(
    Uint8List? bytes,
    String envelope,
  ) async {
    if (bytes == null) return null;
    try {
      final keyId = (jsonDecode(envelope) as Map<String, dynamic>)['keyId'];
      if (bytes.length != 32 ||
          (keyId != null && keyId != await _fingerprint(bytes))) {
        throw PrivateRecoveryFailure.missingKey;
      }
      return SecretKeyData(List<int>.from(bytes), overwriteWhenDestroyed: true);
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  static Future<void> _markRecoveryForRepair(String alias) async {
    try {
      await _storage.write(key: '${alias}_repair', value: '1');
    } catch (error) {
      debugPrint(
        'Could not mark private recovery for repair: ${error.runtimeType}',
      );
    }
  }

  static Future<T?> _deviceRecoveryCall<T>(
    String method,
    Object? arguments,
  ) async {
    try {
      return await invokeOwnedPlatformValue<T>(_channel, method, arguments);
    } on PlatformException catch (error) {
      debugPrint('Private device recovery ($method): ${error.code}');
      throw switch (error.code) {
        'no_screen_lock' => PrivateRecoveryFailure.noScreenLock,
        'recovery_key_missing' ||
        'recovery_key_invalid' => PrivateRecoveryFailure.missingKey,
        'recovery_key_access_failed' => PrivateRecoveryFailure.unreadableKey,
        'recovery_setup_failed' => PrivateRecoveryFailure.setup,
        'recovery_busy' => PrivateRecoveryFailure.busy,
        _ => PrivateRecoveryFailure.prompt,
      };
    } on MissingPluginException {
      throw PrivateRecoveryFailure.prompt;
    }
  }

  @visibleForTesting
  static Future<T?> invokeOwnedPlatformValue<T>(
    MethodChannel channel,
    String method,
    Object? arguments,
  ) async {
    final value = await channel.invokeMethod<T>(method, arguments);
    // Flutter's platform reply may back byte lists with a read-only buffer.
    // Callers can wipe their own copy once the cryptographic operation ends.
    return value is Uint8List ? Uint8List.fromList(value) as T : value;
  }

  // Bind the optional key copy to strong biometrics in Android Keystore on every access
  static FlutterSecureStorage _biometricStorage(String namespace) =>
      FlutterSecureStorage(
        iOptions: IOSOptions(
          accountName: namespace,
          accessibility: KeychainAccessibility.passcode,
          accessControlFlags: const [AccessControlFlag.biometryCurrentSet],
        ),
        aOptions: AndroidOptions.biometric(
          storageNamespace: namespace,
          resetOnError: false,
          migrateOnAlgorithmChange: false,
          enforceBiometrics: true,
          requireBiometricsPerOperation: true,
          biometricType: AndroidBiometricType.strongBiometricOnly,
          biometricPromptTitle: 'Private information',
          biometricPromptSubtitle:
              'Use your fingerprint or secure face recognition',
          biometricPromptNegativeButton: 'Cancel',
        ),
      );

  static Future<String> _fingerprint(List<int> bytes) async =>
      base64UrlEncode((await Sha256().hash(bytes)).bytes);

  static Future<bool> keysMatch(SecretKey first, SecretKey second) async =>
      await _fingerprint(await first.extractBytes()) ==
      await _fingerprint(await second.extractBytes());

  static Future<void> setPassword(SecretKey key, String password) async {
    final scope = await _captureWorkspace();
    final previous = await readPasswordEnvelopeForWorkspace(
      scope.namespace,
      userId: scope.userId,
    );
    final previousData = previous == null
        ? null
        : jsonDecode(previous) as Map<String, dynamic>;
    final bytes = await key.extractBytes();
    final keyId = await _fingerprint(bytes);
    final oldKeyId = previousData?['keyId'];
    if (oldKeyId != null && oldKeyId != keyId) {
      throw const FormatException('The key belongs to a different workspace.');
    }
    final legacyId = previous == null
        ? null
        : (oldKeyId == null
              ? await _fingerprint(utf8.encode(previous))
              : previousData?['legacyId'] as String?);
    await _saveEnvelope(
      await createPasswordEnvelope(key, password, legacyId: legacyId),
      scope: scope,
    );
    passwordRevision.value++;
  }

  static Future<String> createPasswordEnvelope(
    SecretKey key,
    String password, {
    String? legacyId,
  }) async {
    if (password.length < minimumPasswordLength) {
      throw const FormatException(
        'Use at least 6 characters for the private password.',
      );
    }
    final salt = Uint8List.fromList(cipher.newNonce());
    final wrapping = await _passwordWrappingKey(password, salt);
    final bytes = Uint8List.fromList(await key.extractBytes());
    try {
      return await compute(_wrapPasswordEnvelope, (
        bytes,
        wrapping,
        salt,
        legacyId,
      ));
    } finally {
      wrapping.fillRange(0, wrapping.length, 0);
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  static Future<Uint8List> _passwordWrappingKey(
    String password,
    Uint8List salt,
  ) async {
    if (supportsBiometrics) {
      try {
        final native = await invokeOwnedPlatformValue<Uint8List>(
          _cryptoChannel,
          'derivePasswordKey',
          {'password': password, 'salt': salt},
        );
        if (native != null && native.length == 32) return native;
      } on MissingPluginException {
        // Keep the portable derivation available on older builds.
      } on PlatformException catch (error) {
        debugPrint('Private password derivation fallback: ${error.code}');
      }
    }
    return compute(_derivePasswordKey, (password, salt));
  }

  static Future<SecretKeyData> unlockWithPassword(
    String password, {
    required bool isExisting,
  }) async {
    final scope = await _captureWorkspace();
    final envelope = await readPasswordEnvelopeForWorkspace(
      scope.namespace,
      userId: scope.userId,
    );
    if (envelope == null) {
      if (supportsBiometrics &&
          await _storage.containsKey(
            key: _keyForWorkspace(
              'entries_private_biometric_namespace_v1',
              scope.namespace,
            ),
          )) {
        throw const FormatException(
          'Unlock with biometrics first, then add a private password.',
        );
      }
      if (isExisting) {
        throw const FormatException(
          'The private key is missing. Existing private text cannot be recovered here.',
        );
      }
      if (supportsBiometrics && !await hasScreenLock()) {
        throw PrivateRecoveryFailure.noScreenLock;
      }
      final key = await cipher.newSecretKey();
      var stage = 'encrypt envelope';
      try {
        final wrapped = await createPasswordEnvelope(key, password);
        stage = 'save envelope';
        await _saveEnvelope(wrapped, scope: scope);
        passwordRevision.value++;
        // Copy the bytes before destroying the temporary key that owns them
        return SecretKeyData(
          List<int>.from(await key.extractBytes()),
          overwriteWhenDestroyed: true,
        );
      } catch (error) {
        if (kDebugMode) {
          final code = error is PlatformException ? ' (${error.code})' : '';
          debugPrint(
            'Private password setup, $stage: ${error.runtimeType}$code',
          );
        }
        rethrow;
      } finally {
        key.destroy();
      }
    }
    return unlockPasswordEnvelope(envelope, password);
  }

  /// Unlock a backup key without replacing the active workspace password.
  static Future<SecretKeyData> unlockPasswordEnvelope(
    String envelope,
    String password,
  ) async {
    final data = jsonDecode(envelope) as Map<String, dynamic>;
    if (data['v'] != 1) {
      throw const FormatException('Unsupported private key format.');
    }
    final wrapping = await _passwordWrappingKey(
      password,
      base64Decode(data['s'] as String),
    );
    try {
      final bytes = await compute(_unwrapPasswordEnvelope, (data, wrapping));
      return SecretKeyData(bytes, overwriteWhenDestroyed: true);
    } finally {
      wrapping.fillRange(0, wrapping.length, 0);
    }
  }

  static Future<SecretKeyData?> unlockWithBiometrics() async {
    if (!supportsBiometrics) return null;
    final namespace = await _storage.read(key: _biometricNamespace);
    if (namespace == null) return null;
    final List<int>? bytes;
    if (namespace.startsWith(_androidBiometricPrefix)) {
      final sealed = await _storage.read(key: namespace);
      if (sealed == null) return null;
      bytes = await _androidBiometricOperation(
        'unwrapBiometricKey',
        namespace,
        base64Decode(sealed),
      );
    } else {
      // Existing Android enrollments still use their original secure storage.
      final encoded = await _biometricStorage(namespace)
          .read(key: 'private_key');
      bytes = encoded == null ? null : base64Decode(encoded);
    }
    if (bytes == null) return null;
    try {
      final envelope = await readSyncPasswordEnvelope();
      final keyId = envelope == null
          ? null
          : (jsonDecode(envelope) as Map<String, dynamic>)['keyId'];
      if (bytes.length != 32 ||
          (keyId != null && keyId != await _fingerprint(bytes))) {
        return null;
      }
      return SecretKeyData(List<int>.from(bytes), overwriteWhenDestroyed: true);
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  static Future<bool> enableBiometrics(SecretKey key) async {
    if (!supportsBiometrics) {
      throw const FormatException('Biometrics are unavailable on this device.');
    }
    // A fresh namespace also allows re-enrollment after the old biometric key is invalidated
    final suffix = cipher
        .newNonce()
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    final namespace = Platform.isAndroid
        ? '$_androidBiometricPrefix$suffix'
        : 'entries_biometric_$suffix';
    final previous = await _storage.read(key: _biometricNamespace);
    try {
      if (Platform.isAndroid) {
        final bytes = Uint8List.fromList(await key.extractBytes());
        try {
          final sealed = await _androidBiometricOperation(
            'wrapBiometricKey',
            namespace,
            bytes,
          );
          if (sealed == null) {
            await _removeBiometricCopy(namespace);
            return false;
          }
          await _storage.write(key: namespace, value: base64Encode(sealed));
        } finally {
          bytes.fillRange(0, bytes.length, 0);
        }
      } else {
        final vault = _biometricStorage(namespace);
        await vault.write(
          key: 'private_key',
          value: base64Encode(await key.extractBytes()),
        );
        // Creating a Keychain item may succeed before the first Face ID prompt.
        if (await vault.read(key: 'private_key') == null) {
          throw const FormatException(
            'Set up biometrics in your device settings.',
          );
        }
      }
      await _storage.write(key: _biometricNamespace, value: namespace);
    } catch (_) {
      await _removeBiometricCopy(namespace);
      rethrow;
    }
    await _removeBiometricCopy(previous);
    return true;
  }

  static Future<Uint8List?> _androidBiometricOperation(
    String method,
    String namespace,
    Uint8List bytes, {
    bool passcodeOnly = false,
    String? prompt,
  }) async {
    try {
      return await invokeOwnedPlatformValue<Uint8List>(_channel, method, {
        'alias': namespace,
        'data': bytes,
        if (passcodeOnly) 'passcodeOnly': true,
        'prompt': ?prompt,
      });
    } on PlatformException catch (error) {
      throw FormatException(
        error.message ?? 'Android biometrics are unavailable.',
      );
    }
  }

  static Future<void> disableBiometrics() async {
    if (!await hasPassword()) {
      throw const FormatException(
        'Add a private password before disabling biometric access.',
      );
    }
    final namespace = await _storage.read(key: _biometricNamespace);
    await _storage.delete(key: _biometricNamespace);
    await _removeBiometricCopy(namespace);
  }

  static Future<void> _removeBiometricCopy(String? namespace) async {
    if (namespace == null) return;
    try {
      if (namespace.startsWith(_androidBiometricPrefix)) {
        await _storage.delete(key: namespace);
        await _channel.invokeMethod<void>('deleteBiometricKey', {
          'alias': namespace,
        });
      } else {
        await _biometricStorage(namespace).delete(key: 'private_key');
      }
    } catch (_) {
      // An invalidated biometric key is already unusable and must never affect password access
    }
  }

  static Future<String> encrypt(String text, SecretKey key) async {
    if (text.isEmpty) return '';
    final bytes = Uint8List.fromList(await key.extractBytes());
    try {
      return await compute(_encryptPrivateText, (text, bytes));
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  static Future<String> decrypt(String payload, SecretKey key) async {
    if (payload.isEmpty) return '';
    final bytes = Uint8List.fromList(await key.extractBytes());
    try {
      return await compute(_decryptPrivateText, (payload, bytes));
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }
}

Future<String> _wrapPasswordEnvelope(
  (Uint8List, Uint8List, Uint8List, String?) input,
) async {
  final (key, wrappingBytes, salt, legacyId) = input;
  final wrapping = SecretKeyData(wrappingBytes, overwriteWhenDestroyed: true);
  try {
    final box = await PrivateContentStore.cipher.encrypt(
      key,
      secretKey: wrapping,
      aad: PrivateContentStore._passwordContext,
    );
    return jsonEncode({
      'v': 1,
      's': base64Encode(salt),
      'n': base64Encode(box.nonce),
      'c': base64Encode(box.cipherText),
      'm': base64Encode(box.mac.bytes),
      'keyId': await PrivateContentStore._fingerprint(key),
      'legacyId': ?legacyId,
    });
  } finally {
    wrapping.destroy();
    key.fillRange(0, key.length, 0);
  }
}

Future<List<int>> _unwrapPasswordEnvelope(
  (Map<String, dynamic>, Uint8List) input,
) async {
  final (data, wrappingBytes) = input;
  final wrapping = SecretKeyData(wrappingBytes, overwriteWhenDestroyed: true);
  try {
    final bytes = await PrivateContentStore.cipher.decrypt(
      _decodeBox(data),
      secretKey: wrapping,
      aad: PrivateContentStore._passwordContext,
    );
    if (data['keyId'] != null &&
        data['keyId'] != await PrivateContentStore._fingerprint(bytes)) {
      bytes.fillRange(0, bytes.length, 0);
      throw const FormatException('The private information key is invalid.');
    }
    return bytes;
  } on SecretBoxAuthenticationError {
    throw const FormatException('Incorrect private password.');
  } finally {
    wrapping.destroy();
  }
}

Future<String> _encryptPrivateText((String, Uint8List) input) async {
  final (text, bytes) = input;
  final key = SecretKeyData(bytes, overwriteWhenDestroyed: true);
  final plaintext = utf8.encode(text);
  try {
    final box = await PrivateContentStore.cipher.encrypt(
      plaintext,
      secretKey: key,
      aad: PrivateContentStore._context,
    );
    return jsonEncode(_encodeBox(box));
  } finally {
    plaintext.fillRange(0, plaintext.length, 0);
    key.destroy();
  }
}

Future<String> _decryptPrivateText((String, Uint8List) input) async {
  final (payload, bytes) = input;
  final key = SecretKeyData(bytes, overwriteWhenDestroyed: true);
  try {
    final data = jsonDecode(payload) as Map<String, dynamic>;
    if (data['v'] != 1) {
      throw const FormatException('Unsupported private information format.');
    }
    final plaintext = await PrivateContentStore.cipher.decrypt(
      _decodeBox(data),
      secretKey: key,
      aad: PrivateContentStore._context,
    );
    try {
      return utf8.decode(plaintext);
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  } finally {
    key.destroy();
  }
}

Map<String, dynamic> _encodeBox(SecretBox box) => {
  'v': 1,
  'n': base64Encode(box.nonce),
  'c': base64Encode(box.cipherText),
  'm': base64Encode(box.mac.bytes),
};

SecretBox _decodeBox(Map<String, dynamic> data) => SecretBox(
  base64Decode(data['c'] as String),
  nonce: base64Decode(data['n'] as String),
  mac: Mac(base64Decode(data['m'] as String)),
);

Future<Uint8List> _derivePasswordKey((String, List<int>) input) async {
  final passwordKey = SecretKeyData(
    utf8.encode(input.$1),
    overwriteWhenDestroyed: true,
  );
  SecretKey? key;
  try {
    key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 600000,
      bits: 256,
    ).deriveKey(secretKey: passwordKey, nonce: input.$2);
    return Uint8List.fromList(await key.extractBytes());
  } finally {
    key?.destroy();
    passwordKey.destroy();
  }
}
