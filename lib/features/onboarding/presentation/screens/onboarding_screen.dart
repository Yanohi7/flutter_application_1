import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/core/presentation/app_brand.dart';

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../cloud_sync/presentation/cloud_sync_controller.dart';
import '../../../cloud_sync/presentation/cloud_sync_messages.dart';
import '../../../cloud_sync/presentation/google_sign_in_button.dart';
import '../cubit/onboarding_cubit.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  bool _connecting = false;

  void _go(int index) => _pages.animateToPage(
    index,
    duration: const Duration(milliseconds: 240),
    curve: Curves.easeOutCubic,
  );

  Future<void> _connect(CloudSyncController sync) async {
    setState(() => _connecting = true);
    try {
      final onboarding = context.read<OnboardingCubit>();
      await sync.connect(beforeSwitch: onboarding.complete);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final slides = [
      _Slide(
        title: l10n.onboardingCaptureTitle,
        description: l10n.onboardingCaptureDescription,
        art: const _WritingArt(),
      ),
      _Slide(
        title: l10n.onboardingOrganizeTitle,
        description:
            l10n.groupEntriesInCategoriesPinWhatMattersAndFindItAgainWithSearch,
        art: const _CategoryArt(),
      ),
      _Slide(
        title: l10n.onboardingPrivacyTitle,
        description: l10n.onboardingPrivacyDescription,
        art: const _PrivacyArt(),
      ),
      _Slide(
        title: l10n.takeYourEntriesWithYou,
        description: l10n
            .signInWithGoogleToSyncEntriesCategoriesAndAttachmentsAcrossYourDevicesYouCanAlwaysWorkOffline,
        art: const _SyncArt(),
      ),
    ];

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final sync = context.watch<CloudSyncController?>();
    final lastPage = _page == slides.length - 1;
    final complete = context.read<OnboardingCubit>().complete;
    final onboarding = context.watch<OnboardingCubit>().state;
    final busy = onboarding.isSaving || _connecting;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 6, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(appName, style: theme.textTheme.titleLarge),
                    ),
                    TextButton(
                      onPressed: busy ? null : complete,
                      child: Text(AppLocalizations.of(context)!.skip),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  scrollbars: false,
                  dragDevices: {
                    ...ScrollConfiguration.of(context).dragDevices,
                    PointerDeviceKind.mouse,
                  },
                ),
                child: PageView(
                  controller: _pages,
                  physics: busy ? const NeverScrollableScrollPhysics() : null,
                  onPageChanged: (page) => setState(() => _page = page),
                  children: slides,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Column(
                  children: [
                    Semantics(
                      label: AppLocalizations.of(context)!
                          .onboardingPage(_page + 1, slides.length),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var index = 0; index < slides.length; index++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 170),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: index == _page ? 22 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: index == _page
                                    ? colors.primary
                                    : colors.outlineVariant,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 17),
                    if (lastPage && sync != null && !sync.isConnected) ...[
                      if (sync.accountMessage case final String message)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            cloudSyncMessage(
                              context,
                              message,
                              fallback: l10n.couldNotConnectGoogle,
                            ),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      GoogleSignInButton(
                        onPressed: busy || sync.busy
                            ? null
                            : () => _connect(sync),
                      ),
                      if (_connecting) const LinearProgressIndicator(),
                      TextButton(
                        onPressed: busy ? null : complete,
                        child: Text(
                          AppLocalizations.of(context)!.continueOffline,
                        ),
                      ),
                    ] else
                      Row(
                        children: [
                          if (_page > 0)
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: IconButton(
                                tooltip: AppLocalizations.of(context)!.back,
                                onPressed: busy ? null : () => _go(_page - 1),
                                icon: const Icon(Icons.arrow_back),
                              ),
                            ),
                          Expanded(
                            child: FilledButton(
                              onPressed: busy
                                  ? null
                                  : lastPage
                                  ? complete
                                  : () => _go(_page + 1),
                              child: Text(
                                lastPage
                                    ? AppLocalizations.of(context)!
                                          .startUsingEntries
                                    : AppLocalizations.of(context)!.next,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({
    required this.title,
    required this.description,
    required this.art,
  });

  final String title;
  final String description;
  final Widget art;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, box.maxHeight - 16),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: SizedBox(
                      width: 242,
                      height: box.maxHeight < 350 ? 124 : 174,
                      child: FittedBox(
                        child: MediaQuery.withNoTextScaling(child: art),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WritingArt extends StatelessWidget {
  const _WritingArt();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 232,
      height: 162,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 148,
            height: 148,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primaryContainer,
            ),
          ),
          Transform.rotate(
            angle: -.14,
            child: Icon(
              Icons.description_outlined,
              color: colors.onPrimaryContainer,
              size: 96,
            ),
          ),
          Positioned(
            right: 37,
            bottom: 14,
            child: CircleAvatar(
              radius: 24,
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              child: const Icon(Icons.edit_outlined, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryArt extends StatelessWidget {
  const _CategoryArt();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: 232,
      height: 162,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_tree_outlined, color: colors.tertiary, size: 64),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final (label, fill, ink) in [
                (
                  l10n.onboardingWorkCategory,
                  colors.secondaryContainer,
                  colors.onSecondaryContainer,
                ),
                (
                  l10n.onboardingPersonalCategory,
                  colors.tertiaryContainer,
                  colors.onTertiaryContainer,
                ),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrivacyArt extends StatelessWidget {
  const _PrivacyArt();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 232,
      height: 162,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 174,
            height: 106,
            alignment: const Alignment(-0.55, 0),
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Icon(
              Icons.password_rounded,
              size: 52,
              color: colors.onSecondaryContainer,
            ),
          ),
          Positioned(
            right: 36,
            child: CircleAvatar(
              radius: 26,
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              child: const Icon(Icons.lock_outline_rounded, size: 26),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncArt extends StatelessWidget {
  const _SyncArt();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 232,
      height: 162,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(Icons.phone_android_rounded, color: colors.primary, size: 48),
          Icon(Icons.swap_horiz, color: colors.outline, size: 20),
          CircleAvatar(
            radius: 33,
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer,
            child: const Icon(Icons.cloud_sync_outlined, size: 34),
          ),
          Icon(Icons.swap_horiz, color: colors.outline, size: 20),
          Icon(Icons.phone_iphone_rounded, color: colors.primary, size: 48),
        ],
      ),
    );
  }
}
