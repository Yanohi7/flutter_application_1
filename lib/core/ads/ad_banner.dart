import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../presentation/app_preferences.dart';
import 'mobile_ads_service.dart';

class AdBanner extends StatelessWidget {
  const AdBanner({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([appPreferences, entriesAds]),
    builder: (context, _) {
      final id = entriesAds.bannerId;
      if (appPreferences.isPremium || id == null) {
        return const SizedBox.shrink();
      }
      return SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, box) => _BannerSlot(
            key: ValueKey((
              id,
              box.maxWidth.floor(),
              entriesAds.privacyRevision,
            )),
            id: id,
            width: box.maxWidth.floor(),
          ),
        ),
      );
    },
  );
}

class _BannerSlot extends StatefulWidget {
  const _BannerSlot({super.key, required this.id, required this.width});
  final String id;
  final int width;

  @override
  State<_BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<_BannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      if (!await entriesAds.prepare() || !mounted) return;
      final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(
        widget.width,
      );
      if (!mounted || size == null) return;
      final ad = BannerAd(
        adUnitId: widget.id,
        request: const AdRequest(),
        size: size,
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (mounted && identical(_ad, ad)) setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, _) {
            if (!identical(_ad, ad)) return;
            _ad = null;
            unawaited(ad.dispose());
            if (mounted) {
              setState(() => _loaded = false);
              _retry = Timer(const Duration(minutes: 1), _load);
            }
          },
        ),
      );
      _ad = ad;
      await ad.load();
    } catch (error) {
      debugPrint('Banner could not load: ${error.runtimeType}');
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    final ad = _ad;
    _ad = null;
    if (ad != null) unawaited(ad.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Center(
          heightFactor: 1,
          child: SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        ),
      ),
    );
  }
}
