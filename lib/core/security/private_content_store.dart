// Protect private text with a workspace key and independent ways to unlock it.

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PrivateContentStore {
  static final cipher = AesGcm.with256bits();
  static final passwordRevision = ValueNotifier<int>(0);
  static const minimumPasswordLength = 12;
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
    // New private fields have no legacy Windows storage to migrate
    wOptions: WindowsOptions(useBackwardCompatibility: false),
  );
  static String? workspaceNamespace;
  static String _workspaceKey(String key) =>
      workspaceNamespace == null ? key : '${key}_$workspaceNamespace';
  static String get _passwordEnvelope =>
      _workspaceKey('entries_private_password_v1');
  static String get _biometricNamespace =>
      _workspaceKey('entries_private_biometric_namespace_v1');
  static String get _deviceRecoveryKey => _workspaceKey('entries_recovery_v1');
  static final _context = utf8.encode('entries.private-content.v1');
  static const _channel = MethodChannel('entries/privacy');
  static const _androidBiometricPrefix = 'entries_android_biometric_';

  static Future<void> protectScreen(bool value) async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('protectScreen', value);
    }
  }

  static Future<bool> hasPassword() =>
      _storage.containsKey(key: _passwordEnvelope);

  static Future<String?> readSyncPasswordEnvelope() =>
      _storage.read(key: _passwordEnvelope);

  static Future<void> acceptSyncPasswordEnvelope(String envelope) async {
    final current = await readSyncPasswordEnvelope();
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
    await _storage.write(key: _passwordEnvelope, value: envelope);
  }

  static bool get supportsBiometrics => Platform.isAndroid || Platform.isIOS;

  static Future<bool> hasBiometrics() async =>
      supportsBiometrics &&
      await _storage.containsKey(key: _biometricNamespace);

  static Future<bool> hasDeviceRecovery() async =>
      supportsBiometrics && await _storage.containsKey(key: _deviceRecoveryKey);

  static FlutterSecureStorage _iosDeviceRecovery(String account) =>
      FlutterSecureStorage(
        iOptions: IOSOptions(
          accountName: account,
          accessibility: KeychainAccessibility.passcode,
          accessControlFlags: const [AccessControlFlag.userPresence],
          label: 'EntryNote password recovery',
        ),
      );

  // Keep the recovery copy local and require the phone's existing screen lock.
  static Future<void> prepareDeviceRecovery(SecretKey key) async {
    if (!supportsBiometrics) return;
    final alias = _deviceRecoveryKey;
    try {
      if (await _storage.containsKey(key: alias)) return;
      final bytes = Uint8List.fromList(await key.extractBytes());
      try {
        if (Platform.isAndroid) {
          final wrapped = await _androidBiometricOperation(
            'wrapDeviceRecoveryKey',
            alias,
            bytes,
          );
          if (wrapped != null) {
            await _storage.write(key: alias, value: base64Encode(wrapped));
          }
        } else {
          await _iosDeviceRecovery(alias)
              .write(key: 'private_key', value: base64Encode(bytes));
          await _storage.write(key: alias, value: '1');
        }
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
    } catch (_) {
      // Password access must still work on phones without a screen lock.
    }
  }

  static Future<SecretKeyData?> unlockWithDeviceRecovery() async {
    if (!supportsBiometrics) return null;
    final alias = _deviceRecoveryKey;
    final saved = await _storage.read(key: alias);
    if (saved == null) {
      throw const FormatException(
        'Device recovery was not set up on this phone.',
      );
    }
    Uint8List? bytes;
    if (Platform.isAndroid) {
      bytes = await _androidBiometricOperation(
        'unwrapDeviceRecoveryKey',
        alias,
        base64Decode(saved),
      );
    } else {
      try {
        final encoded = await _iosDeviceRecovery(alias)
            .read(key: 'private_key');
        if (encoded != null) bytes = base64Decode(encoded);
      } on PlatformException {
        throw const FormatException(
          'Could not verify your screen lock. Try again or use your recovery file.',
        );
      }
    }
    if (bytes == null) return null;
    try {
      final envelope = await readSyncPasswordEnvelope();
      final keyId = envelope == null
          ? null
          : (jsonDecode(envelope) as Map<String, dynamic>)['keyId'];
      if (bytes.length != 32 ||
          (keyId != null && keyId != await _fingerprint(bytes))) {
        throw const FormatException(
          'This recovery key belongs to a different workspace.',
        );
      }
      return SecretKeyData(List<int>.from(bytes), overwriteWhenDestroyed: true);
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
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

  static Future<void> setPassword(SecretKey key, String password) async {
    if (password.length < minimumPasswordLength) {
      throw const FormatException(
        'Use at least 12 characters for the private password.',
      );
    }
    final storageKey = _passwordEnvelope;
    final previous = await _storage.read(key: storageKey);
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
    final salt = cipher.newNonce();
    final wrappingBytes = await compute(_derivePasswordKey, (password, salt));
    final wrappingKey = SecretKeyData(
      wrappingBytes,
      overwriteWhenDestroyed: true,
    );
    try {
      final box = await cipher.encrypt(
        bytes,
        secretKey: wrappingKey,
        aad: utf8.encode('entries.password-key.v1'),
      );
      await _storage.write(
        key: storageKey,
        value: jsonEncode({
          'v': 1,
          's': base64Encode(salt),
          'n': base64Encode(box.nonce),
          'c': base64Encode(box.cipherText),
          'm': base64Encode(box.mac.bytes),
          'keyId': keyId,
          'legacyId': ?legacyId,
        }),
      );
    } finally {
      wrappingKey.destroy();
    }
    passwordRevision.value++;
  }

  static Future<Uint8List> exportRecoveryFile(SecretKey key) async {
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 'entrynote-recovery-key',
          'version': 1,
          'key': base64UrlEncode(await key.extractBytes()),
        }),
      ),
    );
  }

  static Future<SecretKeyData> unlockWithRecoveryFile(
    Uint8List contents, {
    required String payload,
  }) async {
    final envelope = await readSyncPasswordEnvelope();
    if ((envelope == null && payload.isEmpty) || contents.length > 4096) {
      throw const FormatException('This file cannot unlock this workspace.');
    }
    final decoded = jsonDecode(utf8.decode(contents));
    if (decoded is! Map ||
        decoded['format'] != 'entrynote-recovery-key' ||
        decoded['version'] != 1 ||
        decoded['key'] is! String) {
      throw const FormatException('Choose an EntryNote recovery file.');
    }
    final bytes = base64Url.decode(decoded['key'] as String);
    if (bytes.length != 32) {
      throw const FormatException('The recovery file is invalid.');
    }
    final key = SecretKeyData(bytes, overwriteWhenDestroyed: true);
    try {
      final data = envelope == null
          ? null
          : jsonDecode(envelope) as Map<String, dynamic>;
      final keyId = data?['keyId'];
      if (keyId == null && payload.isNotEmpty) {
        // Existing backups can prove key ownership with an encrypted entry.
        await decrypt(payload, key);
      } else if (keyId != await _fingerprint(bytes)) {
        throw const FormatException(
          'This recovery file belongs to a different workspace.',
        );
      }
      return key;
    } catch (_) {
      key.destroy();
      rethrow;
    }
  }

  static Future<SecretKeyData> unlockWithPassword(
    String password, {
    required bool isExisting,
  }) async {
    final envelope = await _storage.read(key: _passwordEnvelope);
    if (envelope == null) {
      if (await hasBiometrics()) {
        throw const FormatException(
          'Unlock with biometrics first, then add a private password.',
        );
      }
      if (isExisting) {
        throw const FormatException(
          'The private key is missing. Existing private text cannot be recovered here.',
        );
      }
      final key = await cipher.newSecretKey();
      try {
        await setPassword(key, password);
        // Copy the bytes before destroying the temporary key that owns them
        return SecretKeyData(
          List<int>.from(await key.extractBytes()),
          overwriteWhenDestroyed: true,
        );
      } finally {
        key.destroy();
      }
    }
    final data = jsonDecode(envelope) as Map<String, dynamic>;
    if (data['v'] != 1) {
      throw const FormatException('Unsupported private key format.');
    }
    final wrappingKey = SecretKeyData(
      await compute(_derivePasswordKey, (
        password,
        base64Decode(data['s'] as String),
      )),
      overwriteWhenDestroyed: true,
    );
    try {
      final bytes = await cipher.decrypt(
        SecretBox(
          base64Decode(data['c'] as String),
          nonce: base64Decode(data['n'] as String),
          mac: Mac(base64Decode(data['m'] as String)),
        ),
        secretKey: wrappingKey,
        aad: utf8.encode('entries.password-key.v1'),
      );
      if (data['keyId'] != null && data['keyId'] != await _fingerprint(bytes)) {
        throw const FormatException('The private information key is invalid.');
      }
      return SecretKeyData(bytes, overwriteWhenDestroyed: true);
    } on SecretBoxAuthenticationError {
      throw const FormatException('Incorrect private password.');
    } finally {
      wrappingKey.destroy();
    }
  }

  static Future<SecretKeyData?> unlockWithBiometrics() async {
    if (!supportsBiometrics) return null;
    final namespace = await _storage.read(key: _biometricNamespace);
    if (namespace == null) return null;
    if (namespace.startsWith(_androidBiometricPrefix)) {
      final sealed = await _storage.read(key: namespace);
      if (sealed == null) return null;
      final bytes = await _androidBiometricOperation(
        'unwrapBiometricKey',
        namespace,
        base64Decode(sealed),
      );
      return bytes == null
          ? null
          : SecretKeyData(bytes, overwriteWhenDestroyed: true);
    }
    // Existing Android enrollments still use their original secure storage.
    final encoded = await _biometricStorage(namespace).read(key: 'private_key');
    return encoded == null
        ? null
        : SecretKeyData(base64Decode(encoded), overwriteWhenDestroyed: true);
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
    Uint8List bytes,
  ) async {
    try {
      return await _channel.invokeMethod<Uint8List>(method, {
        'alias': namespace,
        'data': bytes,
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
    final box = await cipher.encrypt(
      utf8.encode(text),
      secretKey: key,
      aad: _context,
    );
    return jsonEncode({
      'v': 1,
      'n': base64Encode(box.nonce),
      'c': base64Encode(box.cipherText),
      'm': base64Encode(box.mac.bytes),
    });
  }

  static Future<String> decrypt(String payload, SecretKey key) async {
    if (payload.isEmpty) return '';
    final data = jsonDecode(payload) as Map<String, dynamic>;
    if (data['v'] != 1) {
      throw const FormatException('Unsupported private information format.');
    }
    final box = SecretBox(
      base64Decode(data['c'] as String),
      nonce: base64Decode(data['n'] as String),
      mac: Mac(base64Decode(data['m'] as String)),
    );
    return utf8.decode(
      await cipher.decrypt(box, secretKey: key, aad: _context),
    );
  }
}

// Run deliberate password stretching outside the UI isolate
Future<List<int>> _derivePasswordKey((String, List<int>) input) async {
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
    return List<int>.from(await key.extractBytes());
  } finally {
    key?.destroy();
    passwordKey.destroy();
  }
}
