import 'package:flutter/foundation.dart';

/// AdMob ad unit IDs. Debug builds use Google's test units so we never click our own ads.
class AdIds {
  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

  // Google's test units: https://developers.google.com/admob/flutter/test-ads
  static String get _testInterstitial =>
      _ios ? 'ca-app-pub-3940256099942544/4411468910' : 'ca-app-pub-3940256099942544/1033173712';
  static String get _testRewarded =>
      _ios ? 'ca-app-pub-3940256099942544/1712485313' : 'ca-app-pub-3940256099942544/5224354917';
  static String get _testBanner =>
      _ios ? 'ca-app-pub-3940256099942544/2934735716' : 'ca-app-pub-3940256099942544/6300978111';

  // iOS units: fill in once the iOS app exists in AdMob (same account, see PRODUCTION.md).
  static const _iosInterstitial = '';
  static const _iosRewarded = '';
  static const _iosBanner = '';

  static String get _interstitial => _ios ? _iosInterstitial : 'ca-app-pub-7557144664039757/9251474873';
  static String get _rewarded => _ios ? _iosRewarded : 'ca-app-pub-7557144664039757/3947177308';
  static String get _banner => _ios ? _iosBanner : 'ca-app-pub-7557144664039757/2634095636';

  /// False on an iOS release build until the iOS ad units are filled in: the app then runs without ads.
  static bool get configured => !kReleaseMode || _interstitial.isNotEmpty;

  static String get interstitial => kReleaseMode ? _interstitial : _testInterstitial;
  static String get rewarded => kReleaseMode ? _rewarded : _testRewarded;
  static String get banner => kReleaseMode ? _banner : _testBanner;
}
