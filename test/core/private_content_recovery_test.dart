import 'dart:convert';

import 'package:flutter_application_1/core/security/private_content_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const password = 'original private phrase';
  const newPassword = 'replacement private phrase';

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

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
      final file = await PrivateContentStore.exportRecoveryFile(key);

      FlutterSecureStorage.setMockInitialValues({});
      await PrivateContentStore.acceptSyncPasswordEnvelope(backup);
      final recovered = await PrivateContentStore.unlockWithRecoveryFile(
        file,
        payload: payload,
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

  test('rejects a recovery file from a different workspace', () async {
    final key = await PrivateContentStore.unlockWithPassword(
      password,
      isExisting: false,
    );
    addTearDown(key.destroy);
    final wrongKey = await PrivateContentStore.cipher.newSecretKey();
    addTearDown(wrongKey.destroy);
    final wrongFile = await PrivateContentStore.exportRecoveryFile(wrongKey);
    final before = await PrivateContentStore.readSyncPasswordEnvelope();

    await expectLater(
      PrivateContentStore.unlockWithRecoveryFile(wrongFile, payload: ''),
      throwsFormatException,
    );
    expect(await PrivateContentStore.readSyncPasswordEnvelope(), before);
  });

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
    final file = await PrivateContentStore.exportRecoveryFile(key);

    FlutterSecureStorage.setMockInitialValues({});
    await PrivateContentStore.acceptSyncPasswordEnvelope(jsonEncode(legacy));
    final recovered = await PrivateContentStore.unlockWithRecoveryFile(
      file,
      payload: payload,
    );
    addTearDown(recovered.destroy);
    expect(
      await PrivateContentStore.decrypt(payload, recovered),
      'older entry',
    );

    FlutterSecureStorage.setMockInitialValues({});
    final restored = await PrivateContentStore.unlockWithRecoveryFile(
      file,
      payload: payload,
    );
    addTearDown(restored.destroy);
    expect(await PrivateContentStore.decrypt(payload, restored), 'older entry');
  });
}
