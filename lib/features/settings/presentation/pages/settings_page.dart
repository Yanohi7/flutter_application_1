import 'package:flutter/material.dart';

import '../../../../core/ads/mobile_ads_service.dart';
import '../../../../core/presentation/app_preferences.dart';
import '../../../../core/presentation/widgets/app_ui.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../premium/presentation/pages/premium_page.dart';
import '../../../../core/presentation/widgets/wallpaper.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/background_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.preferences});

  final AppPreferences? preferences;
  AppPreferences get _preferences => preferences ?? appPreferences;

  Future<void> _save(
    BuildContext context,
    Future<void> Function() change,
  ) async {
    try {
      await change();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your preferences. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _preferences,
    builder: (context, _) {
      final colors = Theme.of(context).colorScheme;
      final busy = _preferences.isSaving;
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  ReadablePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'App Brightness Theme',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        const Text('Choose a mode, or follow your device.'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final item in [
                              (
                                ThemeMode.light,
                                'Light',
                                Icons.light_mode_outlined,
                              ),
                              (
                                ThemeMode.dark,
                                'Dark',
                                Icons.dark_mode_outlined,
                              ),
                              (
                                ThemeMode.system,
                                'System',
                                Icons.brightness_auto_outlined,
                              ),
                            ])
                              ChoiceChip(
                                avatar: Icon(
                                  item.$3,
                                  size: 18,
                                  color: _preferences.mode == item.$1
                                      ? colors.onPrimary
                                      : colors.onSurfaceVariant,
                                ),
                                label: Text(
                                  item.$2,
                                  style: TextStyle(
                                    color: _preferences.mode == item.$1
                                        ? colors.onPrimary
                                        : colors.onSurface,
                                  ),
                                ),
                                selected: _preferences.mode == item.$1,
                                onSelected: busy
                                    ? null
                                    : (_) => _save(
                                        context,
                                        () => _preferences.setMode(item.$1),
                                      ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  ReadablePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'App Color Theme',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 12,
                          children: [
                            for (final premium in [false, true])
                              for (final palette in AppPalette.presets.where(
                                (item) => item.isPremium == premium,
                              ))
                                _palette(context, palette),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  ReadablePanel(
                    child: BackgroundSettings(preferences: _preferences),
                  ),
                  ListenableBuilder(
                    listenable: entriesAds,
                    builder: (context, _) => !entriesAds.privacyOptionsRequired
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: OutlinedButton(
                              onPressed: () async {
                                if (!await entriesAds.showPrivacyOptions() &&
                                    context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Could not open ad privacy choices.',
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: const Text('Ad privacy choices'),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _palette(BuildContext context, AppPalette palette) {
    final colors = Theme.of(context).colorScheme;
    final selected = _preferences.palette.id == palette.id;
    final locked = !_preferences.canUsePalette(palette);
    return Semantics(
      selected: selected,
      button: true,
      label: '${palette.name}${locked ? ', Premium required' : ''}',
      child: SizedBox(
        width:
            68 *
            (MediaQuery.textScalerOf(context).scale(12) / 12).clamp(1.0, 2.0),
        child: Column(
          children: [
            Tooltip(
              message: '${palette.name}${locked ? ' · Premium' : ''}',
              child: InkResponse(
                key: ValueKey('theme-${palette.id}'),
                radius: 25,
                onTap: _preferences.isSaving
                    ? null
                    : () {
                        if (locked) {
                          showPremiumDialog(
                            context,
                            trialTheme: palette,
                            preferences: _preferences,
                          );
                        } else {
                          _save(
                            context,
                            () => _preferences.setPalette(palette),
                          );
                        }
                      },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? colors.primary
                              : colors.outlineVariant,
                          width: selected ? 2.5 : 1,
                        ),
                      ),
                      child: ClipOval(
                        child: Theme(
                          data: AppTheme.build(
                            Theme.of(context).brightness,
                            palette: palette,
                          ),
                          child: ThemeWallpaper(
                            style: palette.backgroundStyle,
                            preview: true,
                          ),
                        ),
                      ),
                    ),
                    if (locked)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.outlineVariant),
                          ),
                          child: Icon(
                            Icons.lock_outline,
                            size: 12,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              palette.name,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurface,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
