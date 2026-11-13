import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../services/ad_service.dart';
import '../services/leaderboard_service.dart';
import '../services/premium_service.dart';
import '../services/review_service.dart';
import '../services/sound_service.dart';
import '../services/stats_store.dart';

/// App-wide services, available to every screen.
class Services extends InheritedWidget {
  Services({
    super.key,
    required this.stats,
    required this.ads,
    required this.sound,
    required this.today,
    this.classicRandom,
    PremiumService? premium,
    this.review = const NoReviewService(),
    this.leaderboard = const NoLeaderboardService(),
    this.banner,
    this.privacyOptionsRequired,
    this.showPrivacyOptions,
    required super.child,
  }) : premium = premium ?? NoPremiumService();

  final StatsStore stats;
  final AdService ads;
  final SoundService sound;
  final PremiumService premium;
  final ReviewService review;
  final LeaderboardService leaderboard;

  /// Banner ad under the tray; null where there are no banners (web, tests).
  final WidgetBuilder? banner;

  /// Consent form re-entry point (required by AdMob where consent applies); null without ads.
  final ValueListenable<bool>? privacyOptionsRequired;
  final VoidCallback? showPrivacyOptions;

  /// Injectable clock for the daily puzzle.
  final DateTime Function() today;

  /// Piece source of classic games; null deals at random (the app). Tests and staged builds pass a seeded one.
  final Random Function()? classicRandom;

  static Services of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<Services>()!;

  @override
  bool updateShouldNotify(Services old) =>
      old.stats != stats ||
      old.ads != ads ||
      old.sound != sound ||
      old.premium != premium ||
      old.review != review ||
      old.leaderboard != leaderboard ||
      old.banner != banner;
}
