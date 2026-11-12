import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

final entriesAds = MobileAdsService();

enum RewardedAdResult { earned, dismissed, unavailable }

class MobileAdsService extends ChangeNotifier {
  static const _testPublisher = 'ca-app-pub-3940256099942544';
  static const _androidApp = String.fromEnvironment(
    'ENTRIES_ADMOB_ANDROID_APP_ID',
  );
  static const _iosApp = String.fromEnvironment('ENTRIES_ADMOB_IOS_APP_ID');
  static const _androidBanner = String.fromEnvironment(
    'ENTRIES_ADMOB_ANDROID_BANNER_ID',
  );
  static const _iosBanner = String.fromEnvironment(
    'ENTRIES_ADMOB_IOS_BANNER_ID',
  );
  static const _androidRewarded = String.fromEnvironment(
    'ENTRIES_ADMOB_ANDROID_REWARDED_ID',
  );
  static const _iosRewarded = String.fromEnvironment(
    'ENTRIES_ADMOB_IOS_REWARDED_ID',
  );

  bool _enabled = false;
  bool _testAds = false;
  Future<void>? _consent;
  Future<InitializationStatus>? _initialization;
  bool _showingReward = false;
  bool privacyOptionsRequired = false;
  int privacyRevision = 0;

  bool get _android => defaultTargetPlatform == TargetPlatform.android;

  void configure({required bool testAds}) {
    _enabled =
        !kIsWeb && (_android || defaultTargetPlatform == TargetPlatform.iOS);
    _testAds = testAds;
  }

  static final _appIdPattern = RegExp(r'^(ca-app-pub-[0-9]+)~[0-9]+$');
  static final _unitIdPattern = RegExp(r'^(ca-app-pub-[0-9]+)/[0-9]+$');

  String? get bannerId => !_enabled
      ? null
      : _testAds
      ? '$_testPublisher/${_android ? '9214589741' : '2435281174'}'
      : _liveUnit(_android ? _androidBanner : _iosBanner);

  String? get rewardedId => !_enabled
      ? null
      : _testAds
      ? '$_testPublisher/${_android ? '5224354917' : '1712485313'}'
      : _liveUnit(_android ? _androidRewarded : _iosRewarded);

  String? _liveUnit(String id) {
    final publisher = _appIdPattern
        .firstMatch(_android ? _androidApp : _iosApp)
        ?.group(1);
    if (publisher == null || publisher == _testPublisher) return null;
    return _unitIdPattern.firstMatch(id)?.group(1) == publisher ? id : null;
  }

  Future<bool> prepare() async {
    if (bannerId == null && rewardedId == null) return false;
    try {
      await (_consent ??= _requestConsent());
      if (!await ConsentInformation.instance.canRequestAds()) return false;
      await (_initialization ??= MobileAds.instance.initialize());
      return true;
    } catch (error) {
      debugPrint('Ad setup could not finish: ${error.runtimeType}');
      return false;
    }
  }

  Future<void> _requestConsent() async {
    final updated = Completer<bool>();
    void complete(bool success) {
      if (!updated.isCompleted) updated.complete(success);
    }

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => complete(true),
      (_) => complete(false),
    );
    if (await updated.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => false,
    )) {
      await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
    }
    await _refreshPrivacyRequirement();
  }

  Future<void> _refreshPrivacyRequirement() async {
    final status = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    final required = status == PrivacyOptionsRequirementStatus.required;
    if (privacyOptionsRequired == required) return;
    privacyOptionsRequired = required;
    notifyListeners();
  }

  Future<bool> showPrivacyOptions() async {
    try {
      FormError? failure;
      await ConsentForm.showPrivacyOptionsForm((error) => failure = error);
      if (failure != null) return false;
      privacyRevision++;
      await _refreshPrivacyRequirement();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<RewardedAdResult> showRewarded({
    required bool Function() canShow,
  }) async {
    final id = rewardedId;
    if (id == null || _showingReward) return RewardedAdResult.unavailable;
    _showingReward = true;
    RewardedAd? ad;
    try {
      if (!await prepare() || !canShow()) return RewardedAdResult.unavailable;
      final loaded = Completer<RewardedAd?>();
      await RewardedAd.load(
        adUnitId: id,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (value) {
            if (loaded.isCompleted) {
              unawaited(value.dispose());
            } else {
              loaded.complete(value);
            }
          },
          onAdFailedToLoad: (_) {
            if (!loaded.isCompleted) loaded.complete(null);
          },
        ),
      );
      ad = await loaded.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          if (!loaded.isCompleted) loaded.complete(null);
          return null;
        },
      );
      if (ad == null || !canShow()) return RewardedAdResult.unavailable;
      final completed = Completer<RewardedAdResult>();
      var earned = false;
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (_) {
          if (!completed.isCompleted) {
            completed.complete(
              earned ? RewardedAdResult.earned : RewardedAdResult.dismissed,
            );
          }
        },
        onAdFailedToShowFullScreenContent: (_, _) {
          if (!completed.isCompleted) {
            completed.complete(RewardedAdResult.unavailable);
          }
        },
      );
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
      return await completed.future;
    } catch (error) {
      debugPrint('Rewarded ad could not play: ${error.runtimeType}');
      return RewardedAdResult.unavailable;
    } finally {
      try {
        await ad?.dispose();
      } catch (error) {
        debugPrint('Could not dispose a rewarded ad: ${error.runtimeType}');
      } finally {
        _showingReward = false;
      }
    }
  }
}
