import 'package:flutter/material.dart';

import '../game/game.dart';
import '../game/pieces.dart';
import '../l10n/app_localizations.dart';
import '../services/leaderboard_service.dart';
import '../services/share_text.dart';
import '../services/stats_store.dart';
import 'board_view.dart';
import 'game_screen.dart';
import 'palette.dart';
import 'remove_ads.dart';
import 'services.dart';
import 'share.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Top scores of all players; reloaded after each game.
  Future<Leaderboards?>? _boards;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _boards ??= _loadBoards();
  }

  Future<Leaderboards?> _loadBoards() {
    final services = Services.of(context);
    return services.leaderboard.load(dailyNumberFor(services.today()));
  }

  /// Classic: resume the saved game if there is one.
  Game _classic(StatsStore stats) {
    final saved = stats.savedGame(GameMode.classic.name);
    return saved == null ? Game.classic() : gameFromJson(saved);
  }

  /// Daily: resume today's game; a game left unfinished on an earlier day counts as that day's result.
  Future<Game> _daily(StatsStore stats, int today) async {
    final saved = stats.savedGame(GameMode.daily.name);
    if (saved != null) {
      final game = gameFromJson(saved);
      if (game.dailyNumber == today) return game;
      await stats.recordDaily(DailyResult(
          number: game.dailyNumber!, score: game.score, bestCombo: game.bestCombo, lines: game.linesCleared));
      if (mounted) Services.of(context).leaderboard.submitDaily(game.score, game.dailyNumber!);
      await stats.clearGame(GameMode.daily.name);
    }
    return Game.daily(today);
  }

  Future<void> _open(Game game) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameScreen(game: game)));
    if (!mounted) return;
    setState(() {
      _boards = _loadBoards(); // refresh best score, daily status and boards
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);
    final stats = services.stats;
    final today = dailyNumberFor(services.today());
    final daily = stats.daily(today);
    final streak = stats.dailyStreak(today);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Spacer(),
                const _Logo(),
                const SizedBox(height: 12),
                const Text('BLOCK DAILY',
                    style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.emoji_events_rounded, color: accent),
                  const SizedBox(width: 6),
                  Text(formatScore(stats.bestScore, locale: l10n.localeName),
                      key: const Key('homeBest'),
                      style: const TextStyle(color: accent, fontSize: 20, fontWeight: FontWeight.w800)),
                  FutureBuilder(
                    future: _boards,
                    builder: (_, snap) {
                      final place = snap.data?.classicPlace;
                      if (place == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(medals[place], key: const Key('homeMedal'), style: const TextStyle(fontSize: 20)),
                      );
                    },
                  ),
                ]),
                const Spacer(),
                FilledButton(
                  key: const Key('play'),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: background,
                    minimumSize: const Size.fromHeight(64),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  onPressed: () => _open(_classic(stats)),
                  child: Text(stats.savedGame(GameMode.classic.name) == null ? l10n.play : l10n.continueGame),
                ),
                const SizedBox(height: 16),
                _DailyCard(
                  number: today,
                  score: daily?.score,
                  streak: streak,
                  onPlay: () async => _open(await _daily(stats, today)),
                  onShare: daily == null
                      ? null
                      : () => shareText(context, dailyShareText(daily, streak: streak, l10n: l10n)),
                ),
                const SizedBox(height: 16),
                FutureBuilder(
                  future: _boards,
                  builder: (_, snap) => snap.data == null ? const SizedBox.shrink() : _LeaderboardsView(snap.data!),
                ),
                const Spacer(),
                Text(
                  l10n.instructions,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 8),
                RemoveAdsButtons(premium: services.premium),
                if (!stats.reviewed)
                  TextButton.icon(
                    key: const Key('rate'),
                    onPressed: () async {
                      await stats.setReviewed(true);
                      if (mounted) setState(() {});
                      await services.review.openStoreListing();
                    },
                    icon: const Icon(Icons.star_rounded, color: accent, size: 18),
                    label: Text(l10n.rateApp, style: const TextStyle(color: Colors.white70)),
                  ),
                if (services.privacyOptionsRequired != null)
                  ValueListenableBuilder(
                    valueListenable: services.privacyOptionsRequired!,
                    builder: (_, required, _) => required
                        ? TextButton(
                            key: const Key('privacy'),
                            onPressed: services.showPrivacyOptions,
                            child: Text(l10n.privacyOptions, style: const TextStyle(color: Colors.white38)),
                          )
                        : const SizedBox.shrink(),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.number, required this.score, required this.streak, required this.onPlay, this.onShare});

  final int number;
  final int? score;
  final int streak;
  final VoidCallback onPlay;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final played = score != null;
    final l10n = AppLocalizations.of(context);
    return Material(
      color: const Color(0xFF243B6B),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const Key('daily'),
        borderRadius: BorderRadius.circular(20),
        onTap: played ? onShare : onPlay,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 30),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l10n.dailyTitle(number),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  played ? l10n.dailyPlayed(formatScore(score!, locale: l10n.localeName)) : l10n.dailyNotPlayed,
                  style: const TextStyle(color: Colors.white70),
                ),
              ]),
            ),
            if (streak > 0) Text('🔥 $streak', style: const TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(width: 8),
            Icon(played ? Icons.ios_share_rounded : Icons.play_arrow_rounded, color: accent, size: 30),
          ]),
        ),
      ),
    );
  }
}

const medals = ['🥇', '🥈', '🥉'];

/// Top 3 of all players, scores only; the player's own entry gets a medal.
class _LeaderboardsView extends StatelessWidget {
  const _LeaderboardsView(this.boards);

  final Leaderboards boards;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: const Key('leaderboards'),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(20)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _Board(title: l10n.leaderToday, entries: boards.classicToday)),
        Expanded(child: _Board(title: l10n.leaderAllTime, entries: boards.classicAll)),
        Expanded(child: _Board(title: l10n.leaderDaily, entries: boards.dailyToday)),
      ]),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.title, required this.entries});

  final String title;
  final List<Entry> entries;

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context).localeName;
    return Column(children: [
      Text(title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
      const SizedBox(height: 6),
      if (entries.isEmpty) const Text('—', style: TextStyle(color: Colors.white38, fontSize: 16)),
      for (final (i, e) in entries.indexed)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Text(
            '${e.mine ? medals[i] : '${i + 1}.'} ${formatScore(e.score, locale: locale)}',
            style: TextStyle(
              color: e.mine ? accent : Colors.white,
              fontSize: 16,
              fontWeight: e.mine ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
    ]);
  }
}

/// A few blocks as the logo.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final id in ['l3a', 'o2', 'tb'])
          Padding(padding: const EdgeInsets.all(4), child: PieceView(piece: piecesById[id]!, cell: 26)),
      ]);
}
