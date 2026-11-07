import 'dart:math';

import 'package:block_daily/game/board.dart';
import 'package:block_daily/game/game.dart';
import 'package:block_daily/game/pieces.dart';
import 'package:block_daily/l10n/app_localizations.dart';
import 'package:block_daily/main.dart';
import 'package:block_daily/services/ad_service.dart';
import 'package:block_daily/services/leaderboard_service.dart';
import 'package:block_daily/services/review_service.dart';
import 'package:block_daily/services/sound_service.dart';
import 'package:block_daily/services/stats_store.dart';
import 'package:block_daily/ui/board_view.dart';
import 'package:block_daily/ui/game_screen.dart';
import 'package:block_daily/ui/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'leaderboard_test.dart' show FakeLeaderboard;
import 'review_test.dart' show FakeReview;

class FakeAds implements AdService {
  int interstitials = 0;
  int rewarded = 0;
  @override
  Future<void> showInterstitial() async => interstitials++;
  @override
  Future<bool> showRewarded() async {
    rewarded++;
    return true;
  }
}

final today = DateTime(2026, 10, 25); // daily #6

void checkerboard(Board b) {
  for (var r = 0; r < Board.size; r++) {
    for (var c = 0; c < Board.size; c++) {
      b.cells[r * Board.size + c] = (r + c).isEven ? 1 : 0;
    }
  }
}

void main() {
  late StatsStore stats;
  late FakeAds ads;
  late NoSound sound;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    stats = await StatsStore.open();
    ads = FakeAds();
    sound = NoSound();
  });

  Future<void> pumpGame(WidgetTester tester, Game game, {Locale? locale, ReviewService? review, LeaderboardService? leaderboard}) async {
    tester.view.physicalSize = const Size(412, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(Services(
      stats: stats,
      ads: ads,
      sound: sound,
      review: review ?? const NoReviewService(),
      leaderboard: leaderboard ?? const NoLeaderboardService(),
      today: () => today,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GameScreen(game: game),
      ),
    ));
  }

  /// Drags the piece in [slot] so its top-left cell lands on (row, col).
  Future<void> drag(WidgetTester tester, Game game, int slot, int row, int col) async {
    final boardRect = tester.getRect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is BoardPainter));
    final cell = BoardPainter.cellSize(boardRect.width);
    final piece = game.tray[slot]!;
    final target = boardRect.topLeft +
        Offset(BoardPainter.padding + col * cell, BoardPainter.padding + row * cell) +
        Offset(piece.cols * cell / 2, piece.rows * cell + cell * 1.6);
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(Key('slot-$slot'))));
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    await gesture.moveTo(target);
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }

  String text(WidgetTester tester, String key) => (tester.widget<Text>(find.byKey(Key(key)))).data!;

  testWidgets('dragging a piece onto the board places it and scores', (tester) async {
    final game = Game.classic(random: Random(4));
    await pumpGame(tester, game);
    final piece = game.tray[0]!;

    await drag(tester, game, 0, 2, 1);
    for (final c in piece.cells) {
      expect(game.board.at(2 + c.r, 1 + c.c), piece.color);
    }
    expect(text(tester, 'score'), '${piece.size}');
    expect(game.tray[0], isNull);
  });

  testWidgets('dropping outside the board does nothing', (tester) async {
    final game = Game.classic(random: Random(4));
    await pumpGame(tester, game);
    await drag(tester, game, 0, 12, 0);
    expect(game.board.isEmpty, isTrue);
    expect(game.tray[0], isNotNull);
  });

  testWidgets('completing a line clears it and shows the combo popup', (tester) async {
    final game = Game.classic(random: Random(4));
    for (var c = 0; c < 7; c++) {
      game.board.cells[7 * Board.size + c] = 3;
    }
    game.tray[0] = piecesById['dot'];
    await pumpGame(tester, game);
    await drag(tester, game, 0, 7, 7);
    expect(game.board.isEmpty, isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('+311'), findsOneWidget); // 1 + 10 + 300 perfect clear
    expect(find.text('PERFECT!'), findsOneWidget);
    expect(sound.played, [Sfx.pick, Sfx.perfect]);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('game over offers one revive through a rewarded ad, then records the best', (tester) async {
    final game = Game.classic(random: Random(4));
    checkerboard(game.board);
    game.tray.setAll(0, [piecesById['dot'], piecesById['o2'], piecesById['o2']]);
    final boards = FakeLeaderboard();
    await pumpGame(tester, game, leaderboard: boards);

    await drag(tester, game, 0, 0, 1);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('No more space'), findsOneWidget);
    expect(stats.bestScore, 0, reason: 'not recorded while a revive is possible');
    expect(boards.classic, isEmpty);

    await tester.tap(find.byKey(const Key('revive')));
    await tester.pump();
    expect(ads.rewarded, 1);
    expect(find.text('No more space'), findsNothing);
    expect(game.isOver, isFalse);

    // Make it end again: no second revive, score recorded as best.
    checkerboard(game.board);
    game.tray.setAll(0, [piecesById['dot'], piecesById['o2'], piecesById['o2']]);
    await tester.pump();
    await drag(tester, game, 0, 0, 3);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('revive')), findsNothing);
    expect(stats.bestScore, game.score);
    expect(boards.classic, [(game.score, 6)], reason: "sent to the shared boards once, on daily #6's day");
    expect(find.text('🏆 New best!'), findsOneWidget);
    expect(find.byKey(const Key('share')), findsOneWidget, reason: 'classic games can be shared too');

    await tester.tap(find.byKey(const Key('again')));
    await tester.pump();
    expect(ads.interstitials, 1);
    expect(text(tester, 'score'), '0');
  });

  testWidgets('new best asks for a rating once the player has a few games behind them', (tester) async {
    final review = FakeReview();
    await stats.recordClassic(0);
    await stats.recordClassic(0); // 2 games: the next one is the third
    final game = Game.classic()..revive(); // no revive left, so the result is recorded right away
    checkerboard(game.board);
    game.tray.setAll(0, [piecesById['dot'], piecesById['o2'], piecesById['o2']]);
    await pumpGame(tester, game, review: review);

    await drag(tester, game, 0, 0, 1);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('🏆 New best!'), findsOneWidget);
    expect(review.requests, 0, reason: 'the player reads "New best!" first');
    await tester.pump(const Duration(milliseconds: 1500));
    expect(review.requests, 1);
    expect(stats.reviewPromptedAt, isNotNull);
  });

  testWidgets('home: rate button opens the store and then disappears', (tester) async {
    final review = FakeReview();
    await tester.pumpWidget(BlockDailyApp(stats: stats, ads: ads, sound: sound, review: review, today: () => today));
    expect(find.text('Rate Block Daily'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rate')));
    await tester.pumpAndSettle();
    expect(review.listings, 1);
    expect(stats.reviewed, isTrue);
    expect(find.byKey(const Key('rate')), findsNothing);
  });

  testWidgets("home: top 3 boards, medal on the player's own score", (tester) async {
    tester.view.physicalSize = const Size(412, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boards = FakeLeaderboard(const Leaderboards(
      classicToday: [Entry(1200), Entry(800, mine: true)],
      classicAll: [Entry(9000), Entry(5000), Entry(4000)],
      dailyToday: [],
    ));
    await tester.pumpWidget(BlockDailyApp(stats: stats, ads: ads, sound: sound, leaderboard: boards, today: () => today));
    await tester.pumpAndSettle();
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('ALL TIME'), findsOneWidget);
    expect(find.text('DAILY'), findsOneWidget);
    expect(find.text('1. 1,200'), findsOneWidget);
    expect(find.text('🥈 800'), findsOneWidget);
    expect(find.text('3. 4,000'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.byKey(const Key('homeMedal')), findsOneWidget);
  });

  testWidgets('home: no boards offline', (tester) async {
    await tester.pumpWidget(BlockDailyApp(stats: stats, ads: ads, sound: sound, leaderboard: FakeLeaderboard(), today: () => today));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('leaderboards')), findsNothing);
    expect(find.byKey(const Key('homeMedal')), findsNothing);
  });

  testWidgets('daily: no revive, result saved once, home shows it', (tester) async {
    tester.view.physicalSize = const Size(412, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boards = FakeLeaderboard();
    await tester.pumpWidget(BlockDailyApp(stats: stats, ads: ads, sound: sound, leaderboard: boards, today: () => today));
    expect(find.text('Daily #6'), findsOneWidget);
    expect(find.text('Same pieces for everyone today'), findsOneWidget);

    await tester.tap(find.byKey(const Key('daily')));
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(GameScreen));
    final game = (state.widget as GameScreen).game;
    expect(game.mode, GameMode.daily);
    checkerboard(game.board);
    game.tray.setAll(0, [piecesById['dot'], piecesById['o2'], piecesById['o2']]);
    await tester.pump();
    await drag(tester, game, 0, 0, 1);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Daily complete!'), findsOneWidget);
    expect(find.byKey(const Key('revive')), findsNothing);
    expect(find.byKey(const Key('share')), findsOneWidget);
    expect(stats.daily(6)!.score, 1);
    expect(boards.daily, [(1, 6)]);

    await tester.tap(find.byKey(const Key('home')));
    await tester.pumpAndSettle();
    expect(find.text('Score 1 · tap to share'), findsOneWidget);
    expect(find.text('🔥 1'), findsOneWidget);
  });

  testWidgets('an unfinished classic game is saved and resumed from home', (tester) async {
    tester.view.physicalSize = const Size(412, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(BlockDailyApp(stats: stats, ads: ads, sound: sound, today: () => today));
    expect(find.text('PLAY'), findsOneWidget);

    await tester.tap(find.byKey(const Key('play')));
    await tester.pumpAndSettle();
    var game = (tester.widget<GameScreen>(find.byType(GameScreen))).game;
    // The new game deals random pieces; use a known one so the drop lands every time.
    game.tray[0] = piecesById['dot'];
    await tester.pump();
    final piece = game.tray[0]!;
    await drag(tester, game, 0, 0, 0);
    await tester.pumpAndSettle();
    expect(stats.savedGame('classic'), isNotNull);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('CONTINUE'), findsOneWidget);

    await tester.tap(find.byKey(const Key('play')));
    await tester.pumpAndSettle();
    game = (tester.widget<GameScreen>(find.byType(GameScreen))).game;
    expect(game.score, piece.size);
    expect(game.board.at(0, 0), piece.color);
  });

  testWidgets('a daily left unfinished yesterday is recorded, today starts fresh', (tester) async {
    final yesterday = Game.daily(5)..score = 42;
    await stats.saveGame('daily', yesterday.toJson());
    tester.view.physicalSize = const Size(412, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boards = FakeLeaderboard();
    await tester.pumpWidget(BlockDailyApp(stats: stats, ads: ads, sound: sound, leaderboard: boards, today: () => today));
    await tester.tap(find.byKey(const Key('daily')));
    await tester.pumpAndSettle();
    expect(stats.daily(5)!.score, 42);
    expect(boards.daily, [(42, 5)]);
    final game = (tester.widget<GameScreen>(find.byType(GameScreen))).game;
    expect(game.dailyNumber, 6);
    expect(game.score, 0);
  });

  testWidgets('mute toggle silences effects', (tester) async {
    final game = Game.classic(random: Random(4));
    await pumpGame(tester, game);
    await tester.tap(find.byKey(const Key('mute')));
    await tester.pump();
    expect(sound.muted, isTrue);
    await drag(tester, game, 0, 0, 0);
    expect(sound.played, isEmpty);
  });

  test('praise grows with the number of lines', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(praiseFor(1, en), '');
    expect(praiseFor(2, en), 'Great!');
    expect(praiseFor(3, en), 'Amazing!');
    expect(praiseFor(5, en), 'Unbelievable!');
    expect(praiseFor(1, en, perfect: true), 'PERFECT!');
  });

  test('praise in French', () {
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(praiseFor(1, fr), '');
    expect(praiseFor(2, fr), 'Bravo\u00A0!');
    expect(praiseFor(3, fr), 'Génial\u00A0!');
    expect(praiseFor(5, fr), 'Incroyable\u00A0!');
    expect(praiseFor(1, fr, perfect: true), 'PARFAIT\u00A0!');
  });

  group('French', () {
    const fr = Locale('fr');

    testWidgets('home screen', (tester) async {
      tester.view.physicalSize = const Size(412, 880);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await stats.recordClassic(18240);
      await tester.pumpWidget(BlockDailyApp(stats: stats, ads: ads, sound: sound, today: () => today, locale: fr));
      expect(find.text('JOUER'), findsOneWidget);
      expect(find.text('Défi #6'), findsOneWidget);
      expect(find.text('Les mêmes pièces pour tous aujourd’hui'), findsOneWidget);
      expect(find.text('Glissez les blocs sur la grille. Remplissez des lignes ou des colonnes pour les effacer.'),
          findsOneWidget);
      expect(find.text('18\u202F240'), findsOneWidget);
    });

    testWidgets('perfect clear callout', (tester) async {
      final game = Game.classic(random: Random(4));
      for (var c = 0; c < 7; c++) {
        game.board.cells[7 * Board.size + c] = 3;
      }
      game.tray[0] = piecesById['dot'];
      await pumpGame(tester, game, locale: fr);
      await drag(tester, game, 0, 7, 7);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('PARFAIT\u00A0!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('classic game over', (tester) async {
      final game = Game.classic(random: Random(4));
      checkerboard(game.board);
      game.tray.setAll(0, [piecesById['dot'], piecesById['o2'], piecesById['o2']]);
      await pumpGame(tester, game, locale: fr);
      await drag(tester, game, 0, 0, 1);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Plus de place'), findsOneWidget);
      expect(find.text('Continuer  ▶ pub'), findsOneWidget);
      expect(find.text('Rejouer'), findsOneWidget);
      expect(find.text('Partager le score'), findsOneWidget);
      expect(find.text('Accueil'), findsOneWidget);
    });

    testWidgets('daily game over', (tester) async {
      final game = Game.daily(6);
      checkerboard(game.board);
      game.tray.setAll(0, [piecesById['dot'], piecesById['o2'], piecesById['o2']]);
      await pumpGame(tester, game, locale: fr);
      expect(find.text('Défi #6'), findsOneWidget);
      await drag(tester, game, 0, 0, 1);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Défi du jour terminé\u00A0!'), findsOneWidget);
      expect(find.text('Partager le résultat'), findsOneWidget);
    });
  });
}
