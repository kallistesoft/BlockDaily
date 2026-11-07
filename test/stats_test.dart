import 'package:block_daily/l10n/app_localizations.dart';
import 'package:block_daily/services/share_text.dart';
import 'package:block_daily/services/stats_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StatsStore stats;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    stats = await StatsStore.open();
  });

  test('best score only goes up', () async {
    expect(await stats.recordClassic(120), isTrue);
    expect(await stats.recordClassic(80), isFalse);
    expect(stats.bestScore, 120);
    expect(stats.gamesPlayed, 2);
  });

  test('daily keeps the first attempt and counts the streak', () async {
    const r = DailyResult(number: 10, score: 500, bestCombo: 3, lines: 9);
    await stats.recordDaily(r);
    await stats.recordDaily(const DailyResult(number: 10, score: 9999, bestCombo: 9, lines: 99));
    expect(stats.daily(10)!.score, 500);

    await stats.recordDaily(const DailyResult(number: 9, score: 1, bestCombo: 0, lines: 0));
    await stats.recordDaily(const DailyResult(number: 7, score: 1, bestCombo: 0, lines: 0));
    expect(stats.dailyStreak(10), 2); // 10, 9 (8 missing)
    expect(stats.dailyStreak(11), 2); // today not played yet: still counts up to yesterday
    expect(stats.dailyStreak(12), 0);
  });

  test('share text', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(formatScore(1234567), '1,234,567');
    expect(formatScore(999), '999');
    const r = DailyResult(number: 42, score: 3450, bestCombo: 7, lines: 24);
    expect(dailyShareText(r, streak: 5, l10n: en),
        'Block Daily #42 🧩\n⭐ 3,450\n🔥🔥🔥🔥🔥 combo x7 · 24 lines\n📅 5-day streak\n$playStoreUrl');
    expect(dailyShareText(const DailyResult(number: 1, score: 12, bestCombo: 0, lines: 0), streak: 1, l10n: en),
        'Block Daily #1 🧩\n⭐ 12\n$playStoreUrl');
    expect(dailyShareText(const DailyResult(number: 3, score: 40, bestCombo: 1, lines: 1), streak: 0, l10n: en),
        'Block Daily #3 🧩\n⭐ 40\n🔥 combo x1 · 1 line\n$playStoreUrl');
    expect(classicShareText(score: 18240, newBest: true, l10n: en), 'Block Daily 🧩\n🏆 New best: 18,240\n$playStoreUrl');
    expect(classicShareText(score: 950, newBest: false, l10n: en), 'Block Daily 🧩\n⭐ 950\n$playStoreUrl');
  });

  test('share text in French', () {
    final fr = lookupAppLocalizations(const Locale('fr'));
    const nnbsp = '\u202F', nbsp = '\u00A0';
    expect(formatScore(1234567, locale: 'fr'), '1${nnbsp}234${nnbsp}567');
    expect(formatScore(18240, locale: 'fr_CA'), '18${nnbsp}240');
    expect(formatScore(999, locale: 'fr'), '999');
    const r = DailyResult(number: 42, score: 3450, bestCombo: 7, lines: 24);
    expect(dailyShareText(r, streak: 5, l10n: fr),
        'Block Daily #42 🧩\n⭐ 3${nnbsp}450\n🔥🔥🔥🔥🔥 combo x7 · 24 lignes\n📅 Série de 5 jours\n$playStoreUrl');
    expect(dailyShareText(const DailyResult(number: 3, score: 40, bestCombo: 1, lines: 1), streak: 2, l10n: fr),
        'Block Daily #3 🧩\n⭐ 40\n🔥 combo x1 · 1 ligne\n📅 Série de 2 jours\n$playStoreUrl');
    expect(classicShareText(score: 18240, newBest: true, l10n: fr),
        'Block Daily 🧩\n🏆 Nouveau record$nbsp: 18${nnbsp}240\n$playStoreUrl');
    expect(classicShareText(score: 950, newBest: false, l10n: fr), 'Block Daily 🧩\n⭐ 950\n$playStoreUrl');
  });

  test('any other language falls back to English', () {
    expect(basicLocaleListResolution([const Locale('de')], AppLocalizations.supportedLocales), const Locale('en'));
    expect(basicLocaleListResolution([const Locale('fr', 'CA')], AppLocalizations.supportedLocales), const Locale('fr'));
  });

  test('shared links point to the store of the phone they are shared from', () {
    expect(storeUrl, playStoreUrl);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(storeUrl, appStoreId.isEmpty ? 'https://kallistesoft.ca/block-daily/' : 'https://apps.apple.com/app/id$appStoreId');
  });
}
