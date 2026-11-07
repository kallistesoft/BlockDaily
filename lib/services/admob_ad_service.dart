import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';
import 'ad_service.dart';

/// Google AdMob (Android and iOS). Ads are preloaded so they show instantly at game over.
class AdMobAdService implements AdService {
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  /// True once consent is settled and the SDK has started; the banner waits for it.
  final ready = ValueNotifier(false);

  /// True where players must be able to change their consent later (EU/UK, some US states).
  final privacyOptionsRequired = ValueNotifier(false);

  /// Asks for consent where the law requires it (EU/UK, some US states), then starts the SDK.
  /// The ad content rating (T) and blocked categories are set in the AdMob console, so they can be tightened without
  /// an app update.
  Future<void> init() async {
    await _gatherConsent();
    privacyOptionsRequired.value = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
    if (!await ConsentInformation.instance.canRequestAds()) return;
    await _askTracking();
    await MobileAds.instance.initialize();
    ready.value = true;
    _loadInterstitial();
    _loadRewarded();
  }

  /// iOS: Apple's App Tracking Transparency prompt, after the consent form as Google recommends. A refusal only
  /// means non-personalized ads.
  Future<void> _askTracking() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      if (await AppTrackingTransparency.trackingAuthorizationStatus == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (_) {}
  }

  Future<void> _gatherConsent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((_) => done.complete()),
      (_) => done.complete(), // offline: use the consent stored from last time
    );
    return done.future;
  }

  /// Reopens the consent form so players can change their choice.
  Future<void> showPrivacyOptions() => ConsentForm.showPrivacyOptionsForm((_) {});

  void _loadInterstitial() => InterstitialAd.load(
        adUnitId: AdIds.interstitial,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) => _interstitial = ad,
          onAdFailedToLoad: (_) => _interstitial = null,
        ),
      );

  void _loadRewarded() => RewardedAd.load(
        adUnitId: AdIds.rewarded,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) => _rewarded = ad,
          onAdFailedToLoad: (_) => _rewarded = null,
        ),
      );

  @override
  Future<void> showInterstitial() async {
    final ad = _interstitial;
    if (ad == null) {
      if (ready.value) _loadInterstitial();
      return;
    }
    _interstitial = null;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) => closed.complete(),
      onAdFailedToShowFullScreenContent: (ad, _) => closed.complete(),
    );
    await ad.show();
    await closed.future;
    ad.dispose();
    _loadInterstitial();
  }

  @override
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (ad == null) {
      if (ready.value) _loadRewarded();
      return false;
    }
    _rewarded = null;
    var earned = false;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) => closed.complete(),
      onAdFailedToShowFullScreenContent: (ad, _) => closed.complete(),
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    await closed.future;
    ad.dispose();
    _loadRewarded();
    return earned;
  }

  /// 320×50 banner for the strip under the tray.
  Widget banner() => ValueListenableBuilder(
        valueListenable: ready,
        builder: (_, ready, _) => ready ? const _Banner() : const SizedBox.shrink(),
      );
}

class _Banner extends StatefulWidget {
  const _Banner();

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ad = BannerAd(
      size: AdSize.banner,
      adUnitId: AdIds.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _loaded = true),
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _ad = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _loaded
      ? SizedBox(width: 320, height: 50, child: AdWidget(ad: _ad!))
      : const SizedBox.shrink();
}
