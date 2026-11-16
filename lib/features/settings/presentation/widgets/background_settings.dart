import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../../core/presentation/app_preferences.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/presentation/widgets/wallpaper.dart';
import '../../../premium/presentation/pages/premium_page.dart';
import '../../data/background_storage.dart';
import '../pages/background_preview_page.dart';

class BackgroundSettings extends StatefulWidget {
  const BackgroundSettings({super.key, required this.preferences});
  final AppPreferences preferences;

  @override
  State<BackgroundSettings> createState() => _BackgroundSettingsState();
}

class _BackgroundSettingsState extends State<BackgroundSettings> {
  bool _working = false;

  void _error(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error is FormatException
              ? error.message
              : AppLocalizations.of(context)!
                    .couldNotSaveYourBackgroundPleaseTryAgain,
        ),
      ),
    );
  }

  Future<void> _choose({bool existing = false}) async {
    final preferences = widget.preferences;
    if (_working || preferences.isSaving) return;
    setState(() => _working = true);
    String? imported;
    bool committed = false;
    try {
      if (!preferences.canChangeBackground && !existing) {
        await showPremiumDialog(
          context,
          trialBackground: true,
          preferences: preferences,
        );
        if (!mounted || !preferences.canChangeBackground) return;
      }
      final path = existing
          ? preferences.backgroundPath
          : (imported = await BackgroundStorage.pick());
      if (path == null || !mounted) return;
      final old = preferences.storedBackgroundPath;
      await Navigator.push<PhotoComposition>(
        context,
        MaterialPageRoute(
          builder: (_) => BackgroundPreviewPage(
            path: path,
            preferences: preferences,
            isExisting: existing,
            onApply: (composition) async {
              await preferences.applyPhoto(
                path,
                composition.x,
                composition.y,
                composition.zoom,
                composition.fade,
                composition.opacity,
              );
              committed = true;
            },
          ),
        ),
      );
      if (committed && old != path) await BackgroundStorage.remove(old);
    } catch (error) {
      _error(error);
    } finally {
      if (!committed && imported != null) {
        await BackgroundStorage.remove(imported);
      }
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _remove() async {
    if (_working || widget.preferences.isSaving) return;
    final confirmed = await confirmPhotoRemoval(
      context,
      title: AppLocalizations.of(context)!.removeBackgroundPhoto,
      message: AppLocalizations.of(context)!
          .yourCurrentColorThemeWillBecomeTheBackgroundAgain,
    );
    if (!confirmed || !mounted) return;
    setState(() => _working = true);
    try {
      final old = widget.preferences.backgroundPath;
      await widget.preferences.setBackground(null);
      await BackgroundStorage.remove(old);
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _previewOpacity() async {
    final preferences = widget.preferences;
    if (_working || preferences.isSaving) return;
    setState(() => _working = true);
    try {
      await Navigator.of(context).push<PhotoComposition>(
        MaterialPageRoute(
          builder: (_) => BackgroundPreviewPage.opacity(
            preferences: preferences,
            onApply: (composition) =>
                preferences.setSurfaceOpacity(composition.opacity),
          ),
        ),
      );
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = widget.preferences;
    final path = preferences.backgroundPath;
    final busy = _working || preferences.isSaving;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.photoBackground, style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(switch (theme.platform) {
          TargetPlatform.android ||
          TargetPlatform.iOS => l10n.phoneBackgroundSizeHint,
          _ =>
            l10n.makeItYoursWithAPhotoPreviewTheCropAndAdjustReadabilityBeforeApplying,
        }),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (path != null) ...[
                  SizedBox(
                    height: 140,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: PhotoWallpaper(
                        path: path,
                        x: preferences.photoX,
                        y: preferences.photoY,
                        zoom: preferences.photoZoom,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _choose(),
                  icon: Icon(
                    !preferences.canChangeBackground
                        ? Icons.lock_outline
                        : Icons.add_photo_alternate_outlined,
                  ),
                  label: Text(
                    _working
                        ? AppLocalizations.of(context)!.pleaseWait
                        : path == null
                        ? AppLocalizations.of(context)!.addBackgroundPhoto
                        : AppLocalizations.of(context)!.changePhoto,
                  ),
                ),
                if (path != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _choose(existing: true),
                    icon: const Icon(Icons.crop),
                    label: Text(AppLocalizations.of(context)!.adjustPhoto),
                  ),
                  TextButton(
                    onPressed: busy ? null : _remove,
                    child: Text(
                      AppLocalizations.of(context)!
                          .removePhotoUseThemeBackground,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: busy ? null : _previewOpacity,
          icon: const Icon(Icons.tune),
          label: Text(
            AppLocalizations.of(context)!
                .opacityPercent((preferences.surfaceOpacity * 100).round()),
          ),
        ),
      ],
    );
  }
}
