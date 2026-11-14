import 'package:flutter_application_1/core/presentation/palette_labels.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../../core/ads/mobile_ads_service.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/presentation/app_preferences.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/presentation/widgets/palette_preview.dart';

Future<void> showPremiumDialog(
  BuildContext context, {
  AppPalette? trialTheme,
  bool trialBackground = false,
  AppPreferences? preferences,
}) => showAppDialog<void>(
  context: context,
  builder: (_) => PremiumDialog(
    trialTheme: trialTheme,
    trialBackground: trialBackground,
    preferences: preferences,
  ),
);

/// Presents Premium benefits until verified store subscriptions are configured.
class PremiumDialog extends StatelessWidget {
  const PremiumDialog({
    super.key,
    this.trialTheme,
    this.trialBackground = false,
    this.preferences,
  });

  final AppPalette? trialTheme;
  final bool trialBackground;
  final AppPreferences? preferences;
  AppPreferences get _preferences => preferences ?? appPreferences;

  Future<void> _preview(BuildContext context) async {
    try {
      await _preferences.setPremiumPreview(!_preferences.premiumPreviewEnabled);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!
                  .couldNotUpdateThePreviewPleaseTryAgain,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _preferences,
    builder: (context, _) {
      final theme = Theme.of(context);
      return AppDialog(
        title: AppLocalizations.of(context)!.getPremium,
        onClose: () => Navigator.pop(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.secondaryContainer,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.workspace_premium_outlined,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)!.makeSpaceForYourIdeas,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(
                      context,
                    )!.beautifulColorThemesAFocusedWorkspaceMoreRoomForWhatMatters,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (trialBackground && entriesAds.rewardedId != null) ...[
              _TrialAction(
                description: AppLocalizations.of(context)!
                    .unlockPhotoBackgroundsFor24Hours,
                completed: _preferences.completedPhotoAds,
                recordReward: _preferences.recordPhotoAd,
                preferences: _preferences,
              ),
              const SizedBox(height: 16),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.palette_outlined),
              title: Text(AppLocalizations.of(context)!.allPremiumColorThemes),
              subtitle: Text(
                AppLocalizations.of(context)!
                    .coordinatedColorsInLightDarkAndSystemModes,
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.block_outlined),
              title: Text(AppLocalizations.of(context)!.anAdFreeWorkspace),
              subtitle: Text(
                AppLocalizations.of(context)!.keepTheFocusOnYourNotes,
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.wallpaper_outlined),
              title: Text(
                AppLocalizations.of(context)!.yourOwnPhotoBackgrounds,
              ),
              subtitle: Text(
                AppLocalizations.of(context)!
                    .customFramingZoomAndInterfaceTransparency,
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.attach_file),
              title: Text(AppLocalizations.of(context)!.unlimitedAttachments),
              subtitle: Text(
                AppLocalizations.of(context)!
                    .addAsManyFilesAsYouLikeWithoutWatchingAds,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 12,
              children: [
                for (final palette in AppPalette.presets.where(
                  (item) => item.isPremium,
                ))
                  SizedBox(
                    width: 80,
                    child: Column(
                      children: [
                        PalettePreview(palette: palette),
                        const SizedBox(height: 4),
                        Text(
                          paletteLabel(context, palette),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (trialTheme != null && entriesAds.rewardedId != null)
              _TrialAction(
                description: AppLocalizations.of(context)!
                    .tryThemeFor24Hours(paletteLabel(context, trialTheme!)),
                completed: _preferences.completedThemeAds(trialTheme!),
                recordReward: () => _preferences.recordThemeAd(trialTheme!),
                preferences: _preferences,
              ),
            if (_preferences.allowPremiumPreview) ...[
              FilledButton(
                onPressed: _preferences.isSaving
                    ? null
                    : () => _preview(context),
                child: Text(
                  _preferences.premiumPreviewEnabled
                      ? AppLocalizations.of(context)!.endPremiumPreview
                      : AppLocalizations.of(context)!.startPremiumPreview,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _preferences.allowPremiumPreview
                  ? AppLocalizations.of(context)!.freePreviewNoPaymentRequired
                  : AppLocalizations.of(context)!.purchasesAreNotAvailableYet,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    },
  );
}

class _TrialAction extends StatefulWidget {
  const _TrialAction({
    required this.description,
    required this.completed,
    required this.recordReward,
    required this.preferences,
  });
  final String description;
  final int completed;
  final Future<bool> Function() recordReward;
  final AppPreferences preferences;

  @override
  State<_TrialAction> createState() => _TrialActionState();
}

class _TrialActionState extends State<_TrialAction> {
  bool _busy = false;
  String? _message;

  Future<void> _watch() async {
    final recordReward = widget.recordReward;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await entriesAds.showRewarded(
        canShow: () => mounted && ModalRoute.isCurrentOf(context) == true,
      );
      if (result == RewardedAdResult.earned) {
        final unlocked = await recordReward();
        if (unlocked && mounted && ModalRoute.isCurrentOf(context) == true) {
          Navigator.pop(context);
        }
      } else if (mounted) {
        _message = result == RewardedAdResult.dismissed
            ? AppLocalizations.of(context)!.finishTheAdForItToCount
            : AppLocalizations.of(context)!
                  .anAdIsUnavailableRightNowTryAgainLater;
      }
    } catch (_) {
      _message = AppLocalizations.of(context)!.couldNotSaveThisReward;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.description),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy || widget.preferences.isSaving ? null : _watch,
          icon: const Icon(Icons.play_circle_outline),
          label: Text(
            _busy
                ? AppLocalizations.of(context)!.loadingAd
                : AppLocalizations.of(context)!
                      .watchAdNumber(widget.completed + 1),
          ),
        ),
        if (_message case final String message)
          Text(message, textAlign: TextAlign.center),
      ],
    );
  }
}
