import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/presentation/app_preferences.dart';
import 'package:flutter_application_1/core/theme/app_palette.dart';

import '../../support/test_preferences_storage.dart';

void main() {
  late TestPreferencesStorage storage;
  late AppPreferences preferences;
  setUp(() {
    storage = TestPreferencesStorage();
    preferences = AppPreferences(storage: storage);
  });
  tearDown(() => preferences.dispose());

  test(
    'Legacy appearance migrates to one palette while preserving photo settings',
    () async {
      storage.values[AppPreferences.storageKey] = jsonEncode({
        'mode': 'dark',
        'accent': 0xFF66A58C,
        'backgroundStyle': 'plain',
        'isPremium': false,
        'surfaceOpacity': 0.25,
      });
      await preferences.load();
      expect(preferences.palette.id, 'green');
      expect(preferences.mode, ThemeMode.dark);
      expect(preferences.isPremium, isFalse);
      await preferences.setMode(ThemeMode.light);
      final saved =
          jsonDecode(storage.values[AppPreferences.storageKey]!) as Map;
      expect(saved.containsKey('accent'), isFalse);
      expect(saved.containsKey('backgroundStyle'), isFalse);
      expect(saved['surfaceOpacity'], 0.25);
      expect(saved.containsKey('backgroundPath'), isTrue);
      final restored = AppPreferences(storage: storage);
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.palette.id, 'green');
      expect(restored.mode, ThemeMode.light);
    },
  );

  test('Premium and invalid persisted palettes fall back safely', () async {
    for (final id in ['ocean', 'removed-theme']) {
      storage.values[AppPreferences.storageKey] = jsonEncode({
        'palette': id,
        'isPremium': false,
      });
      await preferences.load();
      expect(preferences.palette.id, 'graphite');
    }
    expect(
      () => preferences.setPalette(
        AppPalette.presets.firstWhere((p) => p.isPremium),
      ),
      throwsStateError,
    );
  });

  test(
    'Two completed ads unlock only the selected theme and persist its trial',
    () async {
      final premium = AppPalette.presets
          .where((item) => item.isPremium)
          .toList();
      await preferences.load(allowPremiumPreview: false);
      await expectLater(
        () => preferences.setPremiumPreview(true),
        throwsStateError,
      );
      expect(await preferences.recordThemeAd(premium.first), isFalse);
      expect(preferences.completedThemeAds(premium.first), 1);
      expect(preferences.canUsePalette(premium.first), isFalse);
      await preferences.load(allowPremiumPreview: false);
      expect(await preferences.recordThemeAd(premium.first), isTrue);
      expect(preferences.palette.id, premium.first.id);
      expect(preferences.canUsePalette(premium[1]), isFalse);
      expect(preferences.isPremium, isFalse);
      await preferences.load(allowPremiumPreview: false);
      expect(preferences.palette.id, premium.first.id);
    },
  );

  test('A photo trial needs two ads and expires after 24 hours', () async {
    await preferences.load(allowPremiumPreview: false);
    expect(await preferences.recordPhotoAd(), isFalse);
    await preferences.load(allowPremiumPreview: false);
    expect(preferences.canChangeBackground, isFalse);
    expect(await preferences.recordPhotoAd(), isTrue);
    await preferences.applyPhoto('wallpaper.jpg', 0, 0, 1, 0, 1);
    expect(preferences.backgroundPath, 'wallpaper.jpg');

    final saved = jsonDecode(
      storage.values[AppPreferences.storageKey]!,
    ) as Map<String, dynamic>;
    final expiry = DateTime.parse(saved['photoTrialEnds'] as String);
    expect(
      expiry.difference(DateTime.now()).inMinutes,
      inInclusiveRange(1439, 1440),
    );
    saved['photoTrialEnds'] = DateTime.utc(2000).toIso8601String();
    storage.values[AppPreferences.storageKey] = jsonEncode(saved);
    await preferences.load(allowPremiumPreview: false);
    expect(preferences.canChangeBackground, isFalse);
    expect(preferences.backgroundPath, isNull);
  });

  test(
    'Note size defaults to Standard and is remembered for this workspace',
    () async {
      await preferences.load(key: 'test_appearance');
      expect(preferences.noteCardSize, NoteCardSize.standard);
      await preferences.setNoteCardSize(NoteCardSize.compact);
      await preferences.load();
      expect(preferences.noteCardSize, NoteCardSize.standard);
      await preferences.load(key: 'test_appearance');
      expect(preferences.noteCardSize, NoteCardSize.compact);
    },
  );

  test(
    'Failed and concurrent writes never publish an unsaved selection',
    () async {
      storage.pendingWrite = Completer<void>();
      storage.failWrite = true;
      final saving = preferences.setMode(ThemeMode.dark);
      expect(preferences.isSaving, isTrue);
      await expectLater(preferences.setMode(ThemeMode.light), throwsStateError);
      expect(preferences.mode, ThemeMode.system);
      storage.pendingWrite!.complete();
      await expectLater(saving, throwsStateError);
      expect(preferences.mode, ThemeMode.system);
      expect(preferences.isSaving, isFalse);
      storage.failWrite = false;
      await preferences.setMode(ThemeMode.dark);
      expect(preferences.mode, ThemeMode.dark);
    },
  );
}
