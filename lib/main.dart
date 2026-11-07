import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n/app_localizations.dart';

import 'services/ad_service.dart';
import 'services/admob_ad_service.dart';
import 'services/crash_reporting.dart';
import 'services/leaderboard_service.dart';
import 'services/premium_service.dart';
import 'services/review_service.dart';
import 'services/sound_service.dart';
import 'services/stats_store.dart';
import 'services/update_service.dart';
import 'ui/home_screen.dart';
import 'ui/palette.dart';
import 'ui/services.dart';
import 'ui/update_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final stats = await StatsStore.open();
  final firstLaunch = stats.firstLaunch();

  // Real ads and the "Remove Ads" purchase on Android only for now; web and iOS stay ad-free.
  final mobile = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  AdService ads = const NoAdService();
  PremiumService premium = NoPremiumService();
  WidgetBuilder? banner;
  ValueListenable<bool>? privacyOptionsRequired;
  VoidCallback? showPrivacyOptions;
  UpdateService? updates;
  ReviewService review = const NoReviewService();
  LeaderboardService leaderboard = const NoLeaderboardService();
  if (mobile) {
    try {
      await initCrashReporting();
      leaderboard = FirestoreLeaderboardService()..submitBest(stats.bestScore);
    } catch (_) {
      // Never block the game because Firebase couldn't start.
    }
    final admob = AdMobAdService();
    final store = StorePremiumService(stats);
    premium = store;
    ads = PremiumAwareAdService(FrequencyCappedAdService(admob, firstLaunch: firstLaunch), () => store.isPremium);
    banner = (_) => admob.banner();
    privacyOptionsRequired = admob.privacyOptionsRequired;
    showPrivacyOptions = admob.showPrivacyOptions;
    updates = UpdateService();
    review = StoreReviewService();
    admob.init();
    store.init();
    updates.check();
  }

  runApp(BlockDailyApp(
    stats: stats,
    ads: ads,
    premium: premium,
    review: review,
    leaderboard: leaderboard,
    banner: banner,
    privacyOptionsRequired: privacyOptionsRequired,
    showPrivacyOptions: showPrivacyOptions,
    updateStatus: updates?.status,
    onUpdate: updates?.update,
    sound: AudioSoundService(muted: stats.muted, persist: stats.setMuted),
  ));
}

class BlockDailyApp extends StatelessWidget {
  const BlockDailyApp({
    super.key,
    required this.stats,
    required this.ads,
    required this.sound,
    this.premium,
    this.review = const NoReviewService(),
    this.leaderboard = const NoLeaderboardService(),
    this.banner,
    this.privacyOptionsRequired,
    this.showPrivacyOptions,
    this.updateStatus,
    this.onUpdate,
    this.today = DateTime.now,
    this.locale,
  });

  final StatsStore stats;
  final AdService ads;
  final SoundService sound;
  final PremiumService? premium;
  final ReviewService review;
  final LeaderboardService leaderboard;
  final WidgetBuilder? banner;
  final ValueListenable<bool>? privacyOptionsRequired;
  final VoidCallback? showPrivacyOptions;

  /// Force / recommended update from Remote Config; null where it isn't wired (web, tests).
  final ValueListenable<UpdateStatus>? updateStatus;
  final VoidCallback? onUpdate;
  final DateTime Function() today;

  /// Forces a language (tests); null follows the phone, falling back to English.
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return Services(
      stats: stats,
      ads: ads,
      sound: sound,
      premium: premium,
      review: review,
      leaderboard: leaderboard,
      banner: banner,
      privacyOptionsRequired: privacyOptionsRequired,
      showPrivacyOptions: showPrivacyOptions,
      today: today,
      child: MaterialApp(
        title: 'Block Daily',
        debugShowCheckedModeBanner: false,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: accent,
          scaffoldBackgroundColor: background,
        ),
        navigatorKey: _navigator,
        builder: (context, child) => updateStatus == null
            ? child!
            : UpdateGate(status: updateStatus!, onUpdate: onUpdate!, navigatorKey: _navigator, child: child!),
        home: const HomeScreen(),
      ),
    );
  }

  static final _navigator = GlobalKey<NavigatorState>();
}
