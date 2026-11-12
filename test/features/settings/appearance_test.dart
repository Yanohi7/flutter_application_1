import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/presentation/app_preferences.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/theme/app_palette.dart';
import 'package:flutter_application_1/features/settings/presentation/pages/settings_page.dart';
import 'package:flutter_application_1/features/premium/presentation/pages/premium_page.dart';

import '../../support/test_preferences_storage.dart';

void main() {
  test('Panels keep foreground contrast at the minimum opacity', () {
    for (final palette in AppPalette.presets) {
      for (final brightness in Brightness.values) {
        final theme = AppTheme.build(
          brightness,
          palette: palette,
          surfaceOpacity: 0.25,
        );
        final colors = theme.colorScheme;
        for (final photo in [
          Colors.black,
          Colors.white,
          Colors.blue,
          Colors.orange,
        ]) {
          for (final panel in [
            theme.cardTheme.color!,
            theme.appBarTheme.backgroundColor!,
          ]) {
            final background = Color.alphaBlend(
              panel,
              photo,
            ).computeLuminance();
            for (final ink in [
              colors.onSurface,
              colors.onSurfaceVariant,
              colors.primary,
            ]) {
              final foreground = ink.computeLuminance();
              final contrast = foreground > background
                  ? (foreground + 0.05) / (background + 0.05)
                  : (background + 0.05) / (foreground + 0.05);
              expect(
                contrast,
                greaterThanOrEqualTo(4.5),
                reason: '${palette.id}, $brightness',
              );
            }
          }
        }
      }
    }
  });

  testWidgets(
    'Color selection persists; a locked theme opens Premium without selecting it',
    (tester) async {
      final preferences = AppPreferences(storage: TestPreferencesStorage());
      addTearDown(preferences.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SettingsPage(preferences: preferences),
        ),
      );
      expect(find.text('App Brightness Theme'), findsOneWidget);
      expect(find.text('Accent color'), findsNothing);
      expect(find.text('Background'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('theme-sage')));
      await tester.pumpAndSettle();
      expect(preferences.palette.id, 'sage');
      await tester.ensureVisible(find.byKey(const ValueKey('theme-ocean')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('theme-ocean')));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumDialog), findsOneWidget);
      expect(preferences.palette.id, 'sage');
      expect(find.text('Start Premium preview'), findsOneWidget);
      expect(find.text('Activate Premium'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Settings and Premium fit narrow windows, dark mode and large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final preferences = AppPreferences(storage: TestPreferencesStorage());
      addTearDown(preferences.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: SettingsPage(preferences: preferences),
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('theme-ocean')),
        200,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('theme-ocean')));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
