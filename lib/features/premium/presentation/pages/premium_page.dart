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
          const SnackBar(
            content: Text('Could not update the preview. Please try again.'),
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
        title: 'Get Premium',
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
                    'Make space for your ideas',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Beautiful color themes. A focused workspace. More room for what matters.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (trialBackground && entriesAds.rewardedId != null) ...[
              _TrialAction(
                description: 'Unlock photo backgrounds for 24 hours.',
                completed: _preferences.completedPhotoAds,
                recordReward: _preferences.recordPhotoAd,
                preferences: _preferences,
              ),
              const SizedBox(height: 16),
            ],
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.palette_outlined),
              title: Text('All Premium color themes'),
              subtitle: Text(
                'Coordinated colors in Light, Dark and System modes',
              ),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.block_outlined),
              title: Text('An ad-free workspace'),
              subtitle: Text('Keep the focus on your notes'),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.wallpaper_outlined),
              title: Text('Your own photo backgrounds'),
              subtitle: Text('Custom framing, zoom and interface transparency'),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.attach_file),
              title: Text('Unlimited attachments'),
              subtitle: Text(
                'Add as many files as you like without watching ads.',
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
                        Text(palette.name, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (trialTheme != null && entriesAds.rewardedId != null)
              _TrialAction(
                description: 'Try ${trialTheme!.name} for 24 hours.',
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
                      ? 'End Premium preview'
                      : 'Start Premium preview',
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _preferences.allowPremiumPreview
                  ? 'Free preview. No payment required.'
                  : 'Purchases are not available yet.',
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
            ? 'Finish the ad for it to count.'
            : 'An ad is unavailable right now. Try again later.';
      }
    } catch (_) {
      _message = 'Could not save this reward.';
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
            _busy ? 'Loading ad…' : 'Watch ad ${widget.completed + 1} of 2',
          ),
        ),
        if (_message case final String message)
          Text(message, textAlign: TextAlign.center),
      ],
    );
  }
}
