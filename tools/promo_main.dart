// Promo staging entry point: the real app on a staged scene, for the promo videos (promo-studio records them).
//
//   flutter build apk --profile -t tools/promo_main.dart
//   adb shell am start -n ca.kallistesoft.block_daily/.MainActivity \
//       --esal dart_entrypoint_args lang=fr,scenario=combo,seed=2
//
// Not shipped. Settings come as `key=value` launch arguments:
//   lang=en|fr           the app's language (default: the phone's)
//   scenario=high_score|combo|perfect|near_death   a classic game in progress, opened with CONTINUE on the home
//                        screen: board, score, best score and the pieces dealt are fixed by the scenario and its seed
//                        (see promo_scenarios.dart; tools/promo_plan.dart prints the moves that play the scene)
//   seed=3               another board for the same scenario (default 1)
//   daily=24             "today" is the day of Daily #24 (or date=2026-11-12), so the Daily card opens that daily
//                        with its real pieces; nothing else is staged for it
// Every launch starts from a wiped save. No ads at all (the "No ads" purchase reads as owned), no Firebase, no
// online boards (none are shown: the real ones are never faked), no rating or update prompts, no sound.
import 'dart:convert';

import 'package:block_daily/game/game.dart';
import 'package:block_daily/main.dart';
import 'package:block_daily/services/ad_service.dart';
import 'package:block_daily/services/premium_service.dart';
import 'package:block_daily/services/sound_service.dart';
import 'package:block_daily/services/stats_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'promo_scenarios.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final config = <String, String>{
    for (final a in args)
      if (a.contains('=')) a.substring(0, a.indexOf('=')): a.substring(a.indexOf('=') + 1),
  };

  // The staged day: the day of the wanted daily, keeping the time of day.
  final now = DateTime.now();
  final number = int.tryParse(config['daily'] ?? '');
  final day = number != null
      ? dateOfDaily(number)
      : config['date'] != null
          ? DateTime.parse(config['date']!)
          : now;
  final offset = DateTime(day.year, day.month, day.day).difference(DateTime(now.year, now.month, now.day));
  DateTime today() => DateTime.now().add(offset);

  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  await prefs.setInt('firstLaunch', now.subtract(const Duration(days: 21)).millisecondsSinceEpoch);
  await prefs.setBool('premium', true);
  await prefs.setBool('reviewed', true); // no "Rate" button
  await prefs.setInt('games', 37);
  await prefs.setInt('best', 3460);

  Scenario? scenario;
  if (config['scenario'] != null) {
    scenario = buildScenario(config['scenario']!, int.tryParse(config['seed'] ?? '') ?? 1);
    await prefs.setInt('best', scenario.best);
    await prefs.setString('save.${GameMode.classic.name}', jsonEncode(scenario.save()));
  }
  // For the recorder: which scene is on screen (compared with tools/promo_plan.dart's output).
  debugPrint('promo: scenario=${scenario?.name} seed=${scenario?.seed} signature=${scenario?.signature} '
      'daily=${dailyNumberFor(today())}');

  runApp(BlockDailyApp(
    stats: StatsStore(prefs),
    ads: const NoAdService(),
    premium: _OwnedNoAds(),
    sound: NoSound(),
    today: today,
    classicRandom: scenario?.random,
    locale: config['lang'] == null ? null : Locale(config['lang']!),
  ));
}

/// "No ads" already bought: no banner, no interstitials, nothing offered on the home screen.
class _OwnedNoAds extends PremiumService {
  @override
  bool get isPremium => true;
  @override
  bool get available => false;
  @override
  String? get price => null;
  @override
  Future<void> buy() async {}
  @override
  Future<void> restore() async {}
}
