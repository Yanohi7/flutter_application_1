import 'package:flutter_application_1/core/presentation/palette_labels.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../../core/ads/mobile_ads_service.dart';
import '../../../../core/presentation/app_preferences.dart';
import '../../../../core/presentation/widgets/app_ui.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../entry/presentation/pages/private_content_page.dart';
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
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!
                .couldNotSaveYourPreferencesPleaseTryAgain,
          ),
        ),
      );
    }
  }

  String _languageName(BuildContext context, AppLanguage language) =>
      switch (language) {
        AppLanguage.system => AppLocalizations.of(context)!.deviceLanguage,
        AppLanguage.english => 'English',
        AppLanguage.ukrainian => 'Українська',
        AppLanguage.spanish => 'Español',
        AppLanguage.german => 'Deutsch',
        AppLanguage.polish => 'Polski',
      };
  Future<void> _chooseLanguage(BuildContext context) async {
    final language = await showDialog<AppLanguage>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.language),
        children: [
          for (final language in AppLanguage.values)
            ListTile(
              title: Text(_languageName(context, language)),
              trailing: language == _preferences.language
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(dialog, language),
            ),
        ],
      ),
    );
    if (context.mounted &&
        language != null &&
        language != _preferences.language) {
      await _save(context, () => _preferences.setLanguage(language));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _preferences,
    builder: (context, _) {
      final colors = Theme.of(context).colorScheme;
      final busy = _preferences.isSaving;
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.settings)),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  ReadablePanel(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.language),
                      title: Text(AppLocalizations.of(context)!.language),
                      subtitle: Text(
                        _languageName(context, _preferences.language),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: busy ? null : () => _chooseLanguage(context),
                    ),
                  ),
                  const SizedBox(height: 28),
                  ReadablePanel(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.lock_outline),
                      title: Text(AppLocalizations.of(context)!.security),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => const PrivateContentPage(
                            payload: '',
                            isEditable: false,
                            securitySettings: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  ReadablePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.appBrightnessTheme,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppLocalizations.of(context)!
                              .chooseAModeOrFollowYourDevice,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final item in [
                              (
                                ThemeMode.light,
                                AppLocalizations.of(context)!.light,
                                Icons.light_mode_outlined,
                              ),
                              (
                                ThemeMode.dark,
                                AppLocalizations.of(context)!.dark,
                                Icons.dark_mode_outlined,
                              ),
                              (
                                ThemeMode.system,
                                AppLocalizations.of(context)!.system,
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
                          AppLocalizations.of(context)!.appColorTheme,
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
                              child: Text(
                                AppLocalizations.of(context)!.adPrivacyChoices,
                              ),
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
      label:
          '${paletteLabel(context, palette)}${locked ? ', ${AppLocalizations.of(context)!.premiumRequired}' : ''}',
      child: SizedBox(
        width:
            68 *
            (MediaQuery.textScalerOf(context).scale(12) / 12).clamp(1.0, 2.0),
        child: Column(
          children: [
            Tooltip(
              message:
                  '${paletteLabel(context, palette)}${locked ? ' · Premium' : ''}',
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
              paletteLabel(context, palette),
              maxLines: 2,
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
