import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_application_1/core/security/private_content_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const password = 'original private phrase';
  const newPassword = 'replacement private phrase';

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('copies a read-only platform key before it can be wiped', () async {
    const channel = MethodChannel('test/private_crypto');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final reply = const StandardMethodCodec()
        .encodeSuccessEnvelope(Uint8List.fromList(List.filled(32, 7)))
        .asUnmodifiableView();
    messenger.setMockMessageHandler(channel.name, (_) async => reply);
    addTearDown(() => messenger.setMockMessageHandler(channel.name, null));

    final platformKey = (await channel.invokeMethod<Uint8List>('key'))!;
    expect(
      () => platformKey.fillRange(0, platformKey.length, 0),
      throwsUnsupportedError,
    );

    final owned =
        (await PrivateContentStore.invokeOwnedPlatformValue<Uint8List>(
          channel,
          'key',
          null,
        ))!;
    expect(owned, platformKey);
    owned.fillRange(0, owned.length, 0);
    expect(owned, everyElement(0));
    expect(platformKey, everyElement(7));
  });

  test('opens an existing v1 envelope with a Unicode password', () async {
    const envelope =
        '{"v":1,"s":"AAECAwQFBgcICQoL","n":"DA0ODxAREhMUFRYX",'
        '"c":"b8Gq+TlxfxRuY5pw8DEoxQuFO8IBjKlTmgCVsRIBgds=",'
        '"m":"3GUU602uP+8K9iZnjSxs6w==",'
        '"keyId":"Yw3NKWbEM2aRElRIu7JbT_QSpJxzLbLIq8G4WBvXEN0="}';
    const record =
        '{"v":1,"n":"DA0ODxAREhMUFRYX","c":"SF+4Wq/GLdPnkphssVuRN+XTUj5OrLo=",'
        '"m":"SshVQe4VrCJ5arkwIKoCIQ=="}';
    final key = await PrivateContentStore.unlockPasswordEnvelope(
      envelope,
      'Тест 🔐 21',
    );
    addTearDown(key.destroy);
    expect(await PrivateContentStore.decrypt(record, key), 'Старий запис');
    await expectLater(
      PrivateContentStore.unlockPasswordEnvelope(envelope, 'wrong password'),
      throwsFormatException,
    );
  });

  test(
    'restores a synced entry and changes its password with the same key',
    () async {
      final key = await PrivateContentStore.unlockWithPassword(
        password,
        isExisting: false,
      );
      addTearDown(key.destroy);
      final payload = await PrivateContentStore.encrypt('private text', key);
      final backup = (await PrivateContentStore.readSyncPasswordEnvelope())!;

      FlutterSecureStorage.setMockInitialValues({});
      await PrivateContentStore.acceptSyncPasswordEnvelope(backup);
      final recovered = await PrivateContentStore.unlockWithPassword(
        password,
        isExisting: true,
      );
      addTearDown(recovered.destroy);
      expect(
        await PrivateContentStore.decrypt(payload, recovered),
        'private text',
      );
      await PrivateContentStore.setPassword(recovered, newPassword);
      final updated = (await PrivateContentStore.readSyncPasswordEnvelope())!;

      FlutterSecureStorage.setMockInitialValues({});
      await PrivateContentStore.acceptSyncPasswordEnvelope(backup);
      await PrivateContentStore.acceptSyncPasswordEnvelope(updated);
      final unlocked = await PrivateContentStore.unlockWithPassword(
        newPassword,
        isExisting: true,
      );
      addTearDown(unlocked.destroy);
      expect(
        await PrivateContentStore.decrypt(payload, unlocked),
        'private text',
      );
    },
  );

  test('accepts an existing backup with an encrypted entry', () async {
    final key = await PrivateContentStore.unlockWithPassword(
      password,
      isExisting: false,
    );
    addTearDown(key.destroy);
    final current = (await PrivateContentStore.readSyncPasswordEnvelope())!;
    final legacy = jsonDecode(current) as Map<String, dynamic>;
    legacy.remove('keyId');
    final payload = await PrivateContentStore.encrypt('older entry', key);

    FlutterSecureStorage.setMockInitialValues({});
    await PrivateContentStore.acceptSyncPasswordEnvelope(jsonEncode(legacy));
    final recovered = await PrivateContentStore.unlockWithPassword(
      password,
      isExisting: true,
    );
    addTearDown(recovered.destroy);
    expect(
      await PrivateContentStore.decrypt(payload, recovered),
      'older entry',
    );

    final restored = await PrivateContentStore.unlockWithPassword(
      password,
      isExisting: true,
    );
    addTearDown(restored.destroy);
    expect(await PrivateContentStore.decrypt(payload, restored), 'older entry');
  });
}
