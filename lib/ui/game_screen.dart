import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/board.dart';
import '../game/game.dart';
import '../l10n/app_localizations.dart';
import '../services/ad_service.dart';
import '../services/leaderboard_service.dart';
import '../services/review_service.dart';
import '../services/share_text.dart';
import '../services/sound_service.dart';
import '../services/stats_store.dart';
import 'banner_slot.dart';
import 'board_view.dart';
import 'palette.dart';
import 'services.dart';
import 'share.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.game});

  final Game game;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late Game game = widget.game;
  final _stackKey = GlobalKey();
  final _boardKey = GlobalKey();

  // Drag state.
  int? _dragSlot;
  Offset _dragGlobal = Offset.zero;
  Offset _dragLocal = Offset.zero; // finger position inside the stack
  Ghost? _ghost;
  double _cell = 32;

  // Effects.
  late final _clearAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late final _popupAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  List<FlashCell> _flash = const [];
  List<Particle> _particles = const [];
  double _shake = 0; // shake strength in pixels for the current clear
  String _praise = '';
  String _popup = '';

  bool _over = false;
  bool _recorded = false;
  bool _newBest = false;

  late StatsStore _stats;
  late AdService _ads;
  late ReviewService _review;
  late LeaderboardService _leaderboard;
  late DateTime Function() _today;
  Random Function()? _classicRandom;
  late SoundService _sound;
  late AppLocalizations _l10n;

  bool get _isDaily => game.mode == GameMode.daily;
  bool get _canRevive => !_isDaily && !game.revived;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = Services.of(context);
    _stats = services.stats;
    _ads = services.ads;
    _review = services.review;
    _leaderboard = services.leaderboard;
    _today = services.today;
    _classicRandom = services.classicRandom;
    _sound = services.sound;
    _l10n = AppLocalizations.of(context);
  }

  @override
  void dispose() {
    _clearAnim.dispose();
    _popupAnim.dispose();
    super.dispose();
  }

  double get _lift => _cell * 1.6;

  // ---- dragging ----

  void _dragStart(int slot, Offset global) {
    if (_over || game.tray[slot] == null) return;
    setState(() {
      _dragSlot = slot;
      _dragGlobal = global;
      _dragLocal = _toStack(global);
      _ghost = _target();
    });
    _sound.play(Sfx.pick);
  }

  void _dragUpdate(Offset global) {
    if (_dragSlot == null) return;
    setState(() {
      _dragGlobal = global;
      _dragLocal = _toStack(global);
      _ghost = _target();
    });
  }

  void _dragEnd() {
    final ghost = _ghost, slot = _dragSlot;
    setState(() {
      _dragSlot = null;
      _ghost = null;
    });
    if (ghost != null && slot != null) _place(slot, ghost);
  }

  /// Converts in the gesture handler, not in build(): during a rebuild the stack may not be laid out yet.
  Offset _toStack(Offset global) {
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    return box != null && box.hasSize ? box.globalToLocal(global) : _dragLocal;
  }

  /// Board cell under the dragged piece's top-left corner, if the piece fits there.
  Ghost? _target() {
    final piece = game.tray[_dragSlot!]!;
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final topLeft = _dragGlobal - Offset(piece.cols * _cell / 2, piece.rows * _cell + _lift);
    final local = box.globalToLocal(topLeft) - const Offset(BoardPainter.padding, BoardPainter.padding);
    final row = (local.dy / _cell).round(), col = (local.dx / _cell).round();
    if (!game.board.canPlace(piece, row, col)) return null;
    return Ghost(piece, row, col, game.board.preview(piece, row, col));
  }

  void _place(int slot, Ghost ghost) {
    // Snapshot the colors of the lines about to clear, for the animation.
    final after = Board.from(game.board);
    for (final c in ghost.piece.cells) {
      after.cells[(ghost.row + c.r) * Board.size + ghost.col + c.c] = ghost.piece.color;
    }
    final flash = [
      for (var r = 0; r < Board.size; r++)
        for (var c = 0; c < Board.size; c++)
          if (ghost.clear.contains(r, c)) (r: r, c: c, color: after.at(r, c)),
    ];

    final move = game.place(slot, ghost.row, ghost.col);
    if (move.clear.isEmpty) {
      HapticFeedback.selectionClick();
      _sound.play(Sfx.place);
    } else {
      final lines = move.clear.lines;
      lines >= 2 || move.perfect ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact();
      _sound.play(move.perfect ? Sfx.perfect : SoundService.clearFor(move.combo));
      _flash = flash;
      _particles = Particle.burst(flash, lines: lines, seed: game.score);
      _shake = move.perfect ? 10 : (lines >= 2 ? 3.0 + lines * 2 : 0);
      _clearAnim.forward(from: 0);
      _praise = praiseFor(lines, _l10n, perfect: move.perfect);
      _popup = [
        '+${move.points}',
        if (move.combo > 1) _l10n.combo(move.combo),
      ].join('  ');
      _popupAnim.forward(from: 0);
    }
    setState(() {});
    if (game.isOver) {
      Future.delayed(const Duration(milliseconds: 450), _gameOver);
    } else {
      _save();
    }
  }

  void _save() => _stats.saveGame(game.mode.name, game.toJson());

  // ---- end of game ----

  void _gameOver() {
    if (!mounted) return;
    setState(() => _over = true);
    _sound.play(Sfx.gameover);
    if (!_canRevive) _record();
  }

  Future<void> _record() async {
    if (_recorded) return;
    _recorded = true;
    await _stats.clearGame(game.mode.name);
    if (_isDaily) {
      await _stats.recordDaily(DailyResult(
          number: game.dailyNumber!, score: game.score, bestCombo: game.bestCombo, lines: game.linesCleared));
      _leaderboard.submitDaily(game.score, game.dailyNumber!);
    } else {
      final best = await _stats.recordClassic(game.score);
      _leaderboard.submitClassic(game.score, dailyNumberFor(_today()));
      if (mounted) setState(() => _newBest = best);
      if (best) _askForReview();
    }
  }

  /// A new best is the happy moment to ask for a rating; let the player read "New best!" first.
  Future<void> _askForReview() async {
    final prompter = ReviewPrompter(_stats, _review);
    if (!prompter.shouldPrompt) return;
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (mounted && _over) await prompter.onNewBest();
  }

  Future<void> _revive() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await _ads.showRewarded()) {
      messenger.showSnackBar(SnackBar(content: Text(_l10n.noAdAvailable)));
      return;
    }
    setState(() {
      game.revive();
      _over = false;
    });
    _save();
  }

  Future<void> _playAgain() async {
    await _record();
    await _ads.showInterstitial();
    setState(() {
      game = Game.classic(random: _classicRandom?.call());
      _over = _recorded = _newBest = false;
    });
  }

  Future<void> _home() async {
    final navigator = Navigator.of(context);
    await _record();
    await _ads.showInterstitial();
    navigator.pop();
  }

  Future<void> _share() async {
    if (!_isDaily) {
      await shareText(context, classicShareText(score: game.score, newBest: _newBest, l10n: _l10n));
      return;
    }
    final result = _stats.daily(game.dailyNumber!);
    if (result == null) return;
    await shareText(context, dailyShareText(result, streak: _stats.dailyStreak(game.dailyNumber!), l10n: _l10n));
  }

  // ---- layout ----

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final boardSize = min(constraints.maxWidth - 24, constraints.maxHeight * 0.56);
          _cell = BoardPainter.cellSize(boardSize);
          final trayCell = _cell * 0.55;
          final dragging = _dragSlot == null ? null : game.tray[_dragSlot!];
          final finger = _dragLocal;

          return Stack(
            key: _stackKey,
            children: [
              Column(
                children: [
                  _TopBar(
                    title: _isDaily ? _l10n.dailyTitle(game.dailyNumber!) : null,
                    score: game.score,
                    best: max(stats.bestScore, _isDaily ? 0 : game.score),
                    showBest: !_isDaily,
                    combo: game.combo,
                    muted: _sound.muted,
                    onToggleSound: () async {
                      await _sound.setMuted(!_sound.muted);
                      setState(() {});
                    },
                    onBack: () => Navigator.maybePop(context),
                  ),
                  const Spacer(),
                  SizedBox.square(
                    dimension: boardSize,
                    child: AnimatedBuilder(
                      animation: _clearAnim,
                      builder: (context, _) {
                        final t = _clearAnim.value;
                        final shake = t < 0.4 ? sin(t * 70) * _shake * (1 - t / 0.4) : 0.0;
                        return Transform.translate(
                          offset: Offset(shake, shake * 0.4),
                          child: CustomPaint(
                            key: _boardKey,
                            painter: BoardPainter(
                              board: game.board,
                              ghost: _ghost,
                              flash: _flash,
                              particles: _particles,
                              fxT: t,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: trayCell * 5 + 16,
                    child: Row(children: [
                      for (var slot = 0; slot < 3; slot++)
                        Expanded(
                          child: GestureDetector(
                            key: Key('slot-$slot'),
                            behavior: HitTestBehavior.opaque,
                            onPanStart: (d) => _dragStart(slot, d.globalPosition),
                            onPanUpdate: (d) => _dragUpdate(d.globalPosition),
                            onPanEnd: (_) => _dragEnd(),
                            onPanCancel: _dragEnd,
                            child: Center(
                              child: game.tray[slot] == null || slot == _dragSlot
                                  ? const SizedBox.shrink()
                                  : PieceView(
                                      piece: game.tray[slot]!,
                                      cell: trayCell,
                                      opacity: game.board.canPlaceAnywhere(game.tray[slot]!) ? 1 : 0.35,
                                    ),
                            ),
                          ),
                        ),
                    ]),
                  ),
                  const BannerSlot(),
                ],
              ),
              // Praise and points over the board.
              Positioned(
                left: 0,
                right: 0,
                top: constraints.maxHeight * 0.24,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _popupAnim,
                    builder: (context, _) {
                      final t = _popupAnim.value;
                      if (t == 0 || t == 1) return const SizedBox.shrink();
                      final pop = Curves.elasticOut.transform(min(1.0, t * 2.5));
                      final fade = t < 0.7 ? 1.0 : (1 - t) / 0.3;
                      return Opacity(
                        opacity: fade.clamp(0, 1),
                        child: Transform.translate(
                          offset: Offset(0, -30 * t),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            if (_praise.isNotEmpty)
                              Transform.scale(
                                scale: 0.4 + 0.6 * pop,
                                child: Text(_praise, key: const Key('praise'), style: _praiseStyle),
                              ),
                            Text(_popup, key: const Key('popup'), style: _pointsStyle),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (dragging != null)
                Positioned(
                  left: finger.dx - dragging.cols * _cell / 2,
                  top: finger.dy - dragging.rows * _cell - _lift,
                  child: IgnorePointer(child: PieceView(piece: dragging, cell: _cell, opacity: 0.95)),
                ),
              if (_over)
                _GameOverPanel(
                  daily: _isDaily,
                  score: game.score,
                  best: stats.bestScore,
                  newBest: _newBest,
                  canRevive: _canRevive,
                  onRevive: _revive,
                  onPlayAgain: _playAgain,
                  onHome: _home,
                  onShare: _share,
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.score,
    required this.best,
    required this.showBest,
    required this.combo,
    required this.muted,
    required this.onToggleSound,
    required this.onBack,
  });

  final String? title;
  final int score;
  final int best;
  final bool showBest;
  final int combo;
  final bool muted;
  final VoidCallback onToggleSound;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
      child: Column(children: [
        Row(children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70)),
          IconButton(
            key: const Key('mute'),
            onPressed: onToggleSound,
            icon: Icon(muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white54),
          ),
          if (title != null)
            Text(title!, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 16)),
          const Spacer(),
          if (showBest) ...[
            const Icon(Icons.emoji_events_rounded, color: accent, size: 22),
            const SizedBox(width: 4),
            Text(formatScore(best, locale: l10n.localeName),
                key: const Key('best'), style: const TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ]),
        Text(
          formatScore(score, locale: l10n.localeName),
          key: const Key('score'),
          style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900),
        ),
        SizedBox(
          height: 22,
          child: combo > 1
              ? Text('🔥 ${l10n.combo(combo)}',
                  style: const TextStyle(color: Color(0xFFFF8A3D), fontWeight: FontWeight.w800))
              : null,
        ),
      ]),
    );
  }
}

class _GameOverPanel extends StatelessWidget {
  const _GameOverPanel({
    required this.daily,
    required this.score,
    required this.best,
    required this.newBest,
    required this.canRevive,
    required this.onRevive,
    required this.onPlayAgain,
    required this.onHome,
    required this.onShare,
  });

  final bool daily;
  final int score;
  final int best;
  final bool newBest;
  final bool canRevive;
  final VoidCallback onRevive;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final big = FilledButton.styleFrom(
      backgroundColor: accent,
      foregroundColor: background,
      minimumSize: const Size.fromHeight(52),
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    );
    final small = OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.white38),
      minimumSize: const Size.fromHeight(48),
    );
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(daily ? l10n.dailyComplete : l10n.noMoreSpace,
                  style: const TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(formatScore(score, locale: l10n.localeName),
                  key: const Key('finalScore'),
                  style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900)),
              if (newBest)
                Text(l10n.newBest, style: const TextStyle(color: accent, fontSize: 20, fontWeight: FontWeight.w800))
              else if (!daily)
                Text(l10n.bestScore(formatScore(best, locale: l10n.localeName)), style: const TextStyle(color: accent, fontSize: 16)),
              const SizedBox(height: 28),
              if (canRevive) ...[
                FilledButton.icon(
                  key: const Key('revive'),
                  style: big,
                  onPressed: onRevive,
                  icon: const Icon(Icons.play_circle_fill_rounded),
                  label: Text(l10n.reviveWithAd),
                ),
                const SizedBox(height: 12),
              ],
              if (daily)
                FilledButton.icon(
                  key: const Key('share'),
                  style: big,
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: Text(l10n.shareResult),
                )
              else ...[
                OutlinedButton(key: const Key('again'), style: small, onPressed: onPlayAgain, child: Text(l10n.playAgain)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('share'),
                  style: small,
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: Text(l10n.shareScore),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton(key: const Key('home'), style: small, onPressed: onHome, child: Text(l10n.home)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Callout for a clear; single lines get none so the big ones feel special.
String praiseFor(int lines, AppLocalizations l10n, {bool perfect = false}) {
  if (perfect) return l10n.praisePerfect;
  return switch (lines) {
    <= 1 => '',
    2 => l10n.praiseGreat,
    3 => l10n.praiseAmazing,
    _ => l10n.praiseUnbelievable,
  };
}

const _praiseStyle = TextStyle(
  color: Colors.white,
  fontSize: 44,
  fontWeight: FontWeight.w900,
  letterSpacing: 1,
  shadows: [Shadow(blurRadius: 18, color: Color(0xFFFF8A3D)), Shadow(blurRadius: 4, color: Colors.black54)],
);

const _pointsStyle = TextStyle(
  color: accent,
  fontSize: 26,
  fontWeight: FontWeight.w900,
  shadows: [Shadow(blurRadius: 12, color: Colors.black54)],
);
