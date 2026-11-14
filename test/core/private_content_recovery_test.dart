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
