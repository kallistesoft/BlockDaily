// Staged scenes for the promo videos (promo-studio records them): shared by tools/promo_main.dart, which stages a
// scene in the app, and tools/promo_plan.dart, which prints the moves to play. Not shipped.
//
// A classic scenario is a pure function of (name, seed): the starting board, score, best score, the first tray, the
// pieces dealt afterwards and a list of moves that plays the scene. Everything is checked against the game's own
// rules (lib/game) by replaying the moves on a real [Game]. Any seed works; a seed gives the same scene everywhere.
//
// - high_score: a run under way; nine or so placements with several clears, the biggest one passes the best score.
// - combo: two set-up placements, then one piece clears four lines at once.
// - perfect: a few placements that end by clearing the whole board.
// - near_death: an almost full board, two tight fits, then the last piece has a single spot left and clears
//   three or four lines; two more placements on the opened board.
// The daily scene needs no staging beyond the date: [planDaily] finds a strong opening for a daily's real pieces.
import 'dart:math';

import 'package:block_daily/game/board.dart';
import 'package:block_daily/game/game.dart';
import 'package:block_daily/game/pieces.dart';

const scenarioNames = ['high_score', 'combo', 'perfect', 'near_death'];

const _n = Board.size;

/// One placement of the plan, with what the real game answered when it was replayed.
class PlannedMove {
  PlannedMove(this.slot, this.row, this.col);

  final int slot, row, col;
  String piece = '';
  int lines = 0, points = 0, score = 0, combo = 0;
  bool perfect = false;

  /// Tray after the move (a new set once all three are placed).
  List<String?> tray = const [];

  Map<String, dynamic> toJson() => {
        'slot': slot,
        'row': row,
        'col': col,
        'piece': piece,
        'rows': piecesById[piece]!.rows,
        'cols': piecesById[piece]!.cols,
        'lines': lines,
        'points': points,
        'score': score,
        'combo': combo,
        'perfect': perfect,
        'tray': tray,
      };
}

class Scenario {
  Scenario({
    required this.name,
    required this.seed,
    required this.cells,
    required this.tray,
    required this.score,
    required this.best,
    required this.rolls,
    required this.dealSeed,
    required this.moves,
    this.peak = 0,
  });

  final String name;
  final int seed;

  /// The starting board, a palette color per cell (0 = empty).
  final List<int> cells;
  final List<String> tray;
  int score;
  int best;

  /// The pieces dealt first (as rolls of [randomPiece]); after them, pieces come from `Random(dealSeed)`.
  final List<int> rolls;
  final int dealSeed;
  final List<PlannedMove> moves;

  /// Index in [moves] of the scene's big moment.
  int peak;

  /// A saved classic game, as the app stores it (see `GameSave`).
  Map<String, dynamic> save() => {
        'mode': GameMode.classic.name,
        'daily': null,
        'cells': cells,
        'tray': tray,
        'score': score,
        'combo': 0,
        'bestCombo': 0,
        'lines': 0,
        'sinceClear': 0,
        'revived': false,
        'deals': 1,
      };

  /// The piece source the app must use for this scene.
  Random random() => PromoRandom(rolls, Random(dealSeed));

  Game game() => gameFromJson(save(), random: random());

  /// Short fingerprint, logged by the app and printed by the plan, so the recorder can check both agree.
  String get signature {
    var h = 17;
    for (final v in [...cells, score, best, ...rolls, dealSeed, for (final t in tray) piecesById[t]!.color]) {
      h = (h * 31 + v) & 0x3fffffff;
    }
    return h.toRadixString(16);
  }

  Map<String, dynamic> toJson() => {
        'scenario': name,
        'seed': seed,
        'signature': signature,
        'cells': cells,
        'tray': tray,
        'score': score,
        'best': best,
        'moves': [for (final m in moves) m.toJson()],
        'peak': peak,
      };
}

/// Deals the scripted pieces first, then follows [_rest].
class PromoRandom implements Random {
  PromoRandom(List<int> rolls, this._rest) : _rolls = List.of(rolls);

  final List<int> _rolls;
  final Random _rest;

  @override
  int nextInt(int max) => _rolls.isEmpty ? _rest.nextInt(max) : _rolls.removeAt(0);
  @override
  bool nextBool() => _rest.nextBool();
  @override
  double nextDouble() => _rest.nextDouble();
}

/// The roll that makes [randomPiece] deal [p].
int rollOf(Piece p) {
  var roll = 0;
  for (final q in allPieces) {
    if (q.id == p.id) return roll;
    roll += q.weight;
  }
  throw ArgumentError(p.id);
}

/// Builds scenario [name] for [seed]; throws if the name is unknown.
Scenario buildScenario(String name, int seed) {
  final kind = scenarioNames.indexOf(name);
  if (kind < 0) throw ArgumentError('unknown scenario "$name" (one of $scenarioNames)');
  for (var attempt = 0; attempt < 20000; attempt++) {
    final s = ((kind + 1) * 1000003 + seed) * 4099 + attempt;
    final r = Random(s);
    final draft = switch (name) {
      'high_score' => _highScore(r, s),
      'combo' => _combo(r, s),
      'perfect' => _perfect(r, s),
      _ => _nearDeath(r, s),
    };
    if (draft == null) continue;
    final scenario = Scenario(
      name: name,
      seed: seed,
      cells: draft.cells,
      tray: draft.tray,
      score: draft.score,
      best: 0,
      rolls: draft.rolls,
      dealSeed: s,
      moves: draft.moves,
    );
    if (!_replay(scenario.game(), scenario.moves, draft.expect)) continue;
    if (!draft.finish(scenario)) continue;
    return scenario;
  }
  throw StateError('no $name scenario found for seed $seed');
}

/// Plays [moves] on the real game and fills in what happened; false when a move is illegal, clears something other
/// than [expect] (lines per move, where given) or ends the game.
bool _replay(Game game, List<PlannedMove> moves, [List<int?> expect = const []]) {
  for (final (i, m) in moves.indexed) {
    final piece = game.tray[m.slot];
    if (piece == null || !game.canPlace(m.slot, m.row, m.col)) return false;
    final result = game.place(m.slot, m.row, m.col);
    if (i < expect.length && expect[i] != null && expect[i] != result.clear.lines) return false;
    if (game.isOver) return false;
    m
      ..piece = piece.id
      ..lines = result.clear.lines
      ..points = result.points
      ..score = game.score
      ..combo = result.combo
      ..perfect = result.perfect
      ..tray = [for (final p in game.tray) p?.id];
  }
  return true;
}

class _Draft {
  _Draft(this.cells, this.tray, this.score, this.rolls, this.moves, this.expect, this.finish);

  final List<int> cells;
  final List<String> tray;
  final int score;
  final List<int> rolls;
  final List<PlannedMove> moves;
  final List<int?> expect;

  /// Last checks and settings (best score, peak) once the moves are replayed.
  final bool Function(Scenario) finish;
}

// ---- boards ----

typedef _Lines = ({List<int> rows, List<int> cols});

bool _inLines(_Lines l, int i) => l.rows.contains(i ~/ _n) || l.cols.contains(i % _n);

int _filled(Board b) => b.cells.where((v) => v != 0).length;

bool _hasFullLine(Board b) {
  for (var a = 0; a < _n; a++) {
    var inRow = 0, inCol = 0;
    for (var k = 0; k < _n; k++) {
      if (b.at(a, k) != 0) inRow++;
      if (b.at(k, a) != 0) inCol++;
    }
    if (inRow == _n || inCol == _n) return true;
  }
  return false;
}

/// Number of spots where [p] fits.
int _spots(Board b, Piece p) {
  var count = 0;
  for (var r = 0; r <= _n - p.rows; r++) {
    for (var c = 0; c <= _n - p.cols; c++) {
      if (b.canPlace(p, r, c)) count++;
    }
  }
  return count;
}

/// Colors a filled/empty board like a played one: covers it with pieces, each in its own color.
List<int> _colored(Board shape, Random r) {
  final left = Board.from(shape);
  final out = List.filled(_n * _n, 0);
  final pieces = [...allPieces.where((p) => p.size > 1)]..shuffle(r);
  for (var i = 0; i < _n * _n; i++) {
    if (left.cells[i] == 0) continue;
    final at = r.nextInt(pieces.length);
    for (var k = 0; k <= pieces.length; k++) {
      final p = k < pieces.length ? pieces[(at + k) % pieces.length] : piecesById['dot']!; // the dot always fits
      // The piece's first cell goes on cell i.
      final row = i ~/ _n - p.cells.first.r, col = i % _n - p.cells.first.c;
      final cells = [for (final c in p.cells) (row + c.r, col + c.c)];
      if (cells.any((c) => c.$1 < 0 || c.$2 < 0 || c.$1 >= _n || c.$2 >= _n || left.at(c.$1, c.$2) == 0)) continue;
      for (final c in cells) {
        left.cells[c.$1 * _n + c.$2] = 0;
        out[c.$1 * _n + c.$2] = p.color;
      }
      break;
    }
  }
  return out;
}

_Lines _randomLines(Random r, int count, {int? rows}) {
  final nRows = rows ?? r.nextInt(count + 1);
  List<int> pick(int k) => ([for (var i = 0; i < _n; i++) i]..shuffle(r)).take(k).toList()..sort();
  return (rows: pick(nRows), cols: pick(count - nRows));
}

// ---- walking back from an end position ----

class _Step {
  _Step(this.piece, this.row, this.col, this.lines);

  final Piece piece;
  final int row, col, lines;
}

/// Undoes one placement that cleared [lines] ([count] random ones when null): returns the step and turns [board]
/// (filled = 1) into the board before it. Null when no piece could have done it. With [maxSpots], the piece had at
/// most that many spots to go to.
_Step? _unplace(Board board, Random r,
    {_Lines? lines, int count = 0, int minSize = 2, int? maxSpots, bool Function(Piece, int, int)? accept}) {
  var l = lines ?? (rows: <int>[], cols: <int>[]);
  if (lines == null && count > 0) {
    var found = false;
    for (var attempt = 0; attempt < 40 && !found; attempt++) {
      l = _randomLines(r, count);
      found = [for (var i = 0; i < _n * _n; i++) i].every((i) => !_inLines(l, i) || board.cells[i] == 0);
    }
    if (!found) return null;
  }
  final full = Board.from(board);
  for (var i = 0; i < _n * _n; i++) {
    if (_inLines(l, i)) full.cells[i] = 1;
  }
  final lineCount = l.rows.length + l.cols.length;
  final pieces = [...allPieces.where((p) => p.size >= minSize)]..shuffle(r);
  for (final p in pieces) {
    final spots = <(int, int)>[];
    for (var row = 0; row <= _n - p.rows; row++) {
      for (var col = 0; col <= _n - p.cols; col++) {
        if (p.cells.any((c) => full.at(row + c.r, col + c.c) == 0)) continue;
        if (l.rows.any((line) => p.cells.every((c) => row + c.r != line))) continue;
        if (l.cols.any((line) => p.cells.every((c) => col + c.c != line))) continue;
        if (accept != null && !accept(p, row, col)) continue;
        final before = Board.from(full);
        for (final c in p.cells) {
          before.cells[(row + c.r) * _n + col + c.c] = 0;
        }
        if (_hasFullLine(before) || before.preview(p, row, col).lines != lineCount) continue;
        if (maxSpots != null && _spots(before, p) > maxSpots) continue;
        spots.add((row, col));
      }
    }
    if (spots.isEmpty) continue;
    final (row, col) = spots[r.nextInt(spots.length)];
    board.cells.setAll(0, full.cells);
    for (final c in p.cells) {
      board.cells[(row + c.r) * _n + col + c.c] = 0;
    }
    return _Step(p, row, col, lineCount);
  }
  return null;
}

/// Trays (three pieces each, slots shuffled) and moves for [steps] played in order; random pieces fill the last tray.
({List<List<Piece>> trays, List<PlannedMove> moves}) _deal(List<_Step> steps, Random r) {
  final trays = <List<Piece>>[];
  final moves = <PlannedMove>[];
  for (var i = 0; i < steps.length; i += 3) {
    final group = steps.sublist(i, min(i + 3, steps.length));
    final slots = [0, 1, 2]..shuffle(r);
    final tray = [for (var k = 0; k < 3; k++) randomPiece(r)];
    for (final (k, step) in group.indexed) {
      tray[slots[k]] = step.piece;
      moves.add(PlannedMove(slots[k], step.row, step.col));
    }
    trays.add(tray);
  }
  return (trays: trays, moves: moves);
}

_Draft _draft(Board start, List<_Step> steps, Random r, int score, bool Function(Scenario) finish) {
  final dealt = _deal(steps, r);
  return _Draft(
    _colored(start, r),
    [for (final p in dealt.trays.first) p.id],
    score,
    [for (final t in dealt.trays) ...t.map(rollOf)],
    dealt.moves,
    [for (final s in steps) s.lines],
    finish,
  );
}

int _believableScore(Random r, int low, int high) => low + r.nextInt(high - low);

// ---- combo: two set-up placements, then four lines with one piece ----

_Draft? _combo(Random r, int seed) {
  final lines = _randomLines(r, 4);
  final end = Board();
  for (var i = 0; i < _n * _n; i++) {
    if (!_inLines(lines, i) && r.nextInt(100) < 42) end.cells[i] = 1;
  }
  final board = Board.from(end);
  final last = _unplace(board, r, lines: lines);
  if (last == null) return null;
  // The set-up pieces go (mostly) into the lines about to clear.
  bool inBand(Piece p, int row, int col) =>
      p.cells.where((c) => _inLines(lines, (row + c.r) * _n + col + c.c)).length * 2 > p.size;
  final second = _unplace(board, r, minSize: 3, accept: inBand);
  if (second == null) return null;
  final first = _unplace(board, r, minSize: 3, accept: inBand);
  if (first == null) return null;
  return _draft(board, [first, second, last], r, _believableScore(r, 180, 900), (s) {
    s
      ..peak = 2
      ..best = s.score + 900 + r.nextInt(2400);
    return true;
  });
}

// ---- perfect: a few placements, the last one empties the board ----

_Draft? _perfect(Random r, int seed) {
  // Lines cleared by each move; the last clear leaves nothing.
  final pattern = const [
    [1, 0, 0, 2],
    [2, 0, 0, 2],
    [0, 2, 0, 2],
    [0, 1, 0, 3],
    [1, 0, 2, 0, 2],
    [0, 2, 0, 3],
  ][r.nextInt(6)];
  final board = Board();
  final steps = <_Step>[];
  for (final (i, count) in pattern.reversed.indexed) {
    final step = _unplace(board, r, count: count, minSize: i == 0 ? 1 : 2);
    if (step == null) return null;
    steps.insert(0, step);
  }
  final filled = _filled(board);
  if (filled < 22 || filled > 40) return null;
  return _draft(board, steps, r, _believableScore(r, 240, 1400), (s) {
    s
      ..peak = s.moves.length - 1
      ..best = s.score + 1500 + r.nextInt(2600);
    return s.moves.last.perfect;
  });
}

// ---- near death: almost full, two tight fits, then the only spot left clears 3–4 lines ----

_Draft? _nearDeath(Random r, int seed) {
  final count = 3 + r.nextInt(2);
  final lines = _randomLines(r, count, rows: 1 + r.nextInt(count - 1));
  // After the save: everything outside the cleared lines is full, but for one hole in each row and column.
  final end = Board();
  for (var i = 0; i < _n * _n; i++) {
    if (!_inLines(lines, i)) end.cells[i] = 1;
  }
  final rows = [for (var i = 0; i < _n; i++) if (!lines.rows.contains(i)) i]..shuffle(r);
  final cols = [for (var i = 0; i < _n; i++) if (!lines.cols.contains(i)) i]..shuffle(r);
  for (var k = 0; k < max(rows.length, cols.length); k++) {
    end.cells[rows[k % rows.length] * _n + cols[k % cols.length]] = 0;
  }
  final board = Board.from(end);
  final save = _unplace(board, r, lines: lines, minSize: 3, maxSpots: 1);
  if (save == null) return null;
  final second = _unplace(board, r, minSize: 3, maxSpots: 3);
  if (second == null) return null;
  final first = _unplace(board, r, minSize: 3, maxSpots: 4);
  if (first == null) return null;
  // At the start the saving piece fits nowhere or in one spot only, and the board is over 70 % full.
  if (_spots(board, save.piece) > 1 || _filled(board) < 46) return null;
  final draft = _draft(board, [first, second, save], r, _believableScore(r, 1900, 5200), (s) {
    s
      ..peak = 2
      ..best = s.moves.last.score + 800 + r.nextInt(3000);
    return s.moves.length == 5;
  });
  // Two calm placements on the opened board, from the pieces the game deals next.
  final after = Board.from(end);
  final next = Random(seed);
  final tray = <Piece?>[for (var i = 0; i < 3; i++) randomPiece(next)];
  final tail = _search(_Node(after, tray, 0, 0, 0, 0), [for (var i = 0; i < 12; i++) randomPiece(next)], 2)
      .where((n) => n.path.every((m) => m.lines == 0));
  if (tail.isEmpty) return null;
  draft.moves.addAll([for (final m in tail.first.path) PlannedMove(m.slot, m.row, m.col)]);
  return draft;
}

// ---- high score: a run under way, the biggest clear passes the best ----

_Draft? _highScore(Random r, int seed) {
  // Lines cleared by each move: several clears, the biggest one late.
  final pattern = const [
    [0, 1, 0, 0, 1, 0, 0, 3, 0],
    [1, 0, 0, 1, 0, 2, 0, 3, 0],
    [0, 0, 1, 0, 2, 0, 0, 1, 3],
    [0, 1, 0, 1, 0, 0, 1, 0, 3, 0],
    [0, 2, 0, 0, 1, 0, 1, 4],
    [0, 0, 1, 0, 1, 0, 2, 0, 3, 0],
  ][r.nextInt(6)];
  // The position at the end: loose blocks, with a few lines left empty (the ones just cleared).
  final open = _randomLines(r, 3 + r.nextInt(2));
  final board = Board();
  for (var i = 0; i < _n * _n; i++) {
    if (!_inLines(open, i) && r.nextInt(100) < 50) board.cells[i] = 1;
  }
  if (_hasFullLine(board)) return null;
  final steps = <_Step>[];
  for (final count in pattern.reversed) {
    final step = _unplace(board, r, count: count);
    if (step == null) return null;
    steps.insert(0, step);
  }
  final filled = _filled(board);
  if (filled < 26 || filled > 44) return null;
  final peak = pattern.indexOf(pattern.reduce(max));
  return _draft(board, steps, r, _believableScore(r, 1400, 4600), (s) {
    final before = s.moves[peak - 1].score, points = s.moves[peak].points;
    s
      ..peak = peak
      ..best = before + points ~/ 4 + r.nextInt(points ~/ 2);
    return s.best > before && s.best < s.moves[peak].score;
  });
}

// ---- search (beam) over the game's rules ----

/// A position reached during the search. Scoring follows [Game.place]; the plan is replayed on a real [Game]
/// afterwards, so a mismatch can't go unnoticed.
class _Node {
  _Node(this.board, this.tray, this.score, this.combo, this.since, this.next, [this.parent, this.move, this.flair = 0]);

  final Board board;
  final List<Piece?> tray;
  final int score, combo, since;

  /// Extra taste for clears of several lines at once (they make the better video).
  final int flair;

  /// Index of the next piece to deal.
  final int next;
  final _Node? parent;
  final ({int slot, int row, int col, int lines, int points})? move;

  List<({int slot, int row, int col, int lines, int points})> get path =>
      [if (parent != null) ...parent!.path, ?move];

  /// Score plus a taste for tidy boards: full-ish lines, few closed-in holes.
  late final double value = _value(1, 0.12);

  /// The same with little weight on the score and more on lines filling up: holds back single clears, so that
  /// several lines can go at once.
  late final double patientValue = _value(0.25, 0.6);

  double _value(double perPoint, double perLine) {
    var v = score * perPoint + flair;
    for (var a = 0; a < _n; a++) {
      var inRow = 0, inCol = 0;
      for (var b = 0; b < _n; b++) {
        if (board.at(a, b) != 0) inRow++;
        if (board.at(b, a) != 0) inCol++;
      }
      v += (inRow * inRow + inCol * inCol) * perLine;
    }
    for (var row = 0; row < _n; row++) {
      for (var col = 0; col < _n; col++) {
        if (board.at(row, col) != 0) continue;
        bool wall(int rr, int cc) => rr < 0 || cc < 0 || rr >= _n || cc >= _n || board.at(rr, cc) != 0;
        if (wall(row - 1, col) && wall(row + 1, col) && wall(row, col - 1) && wall(row, col + 1)) v -= 6;
      }
    }
    return v - _filled(board) * 0.8;
  }
}

/// The best positions after [depth] placements, best first. [draws] are the pieces dealt next, three at a time.
/// Positions where the game would end (or, in a classic game, deal again because nothing fits) are dropped.
List<_Node> _search(_Node start, List<Piece> draws, int depth,
    {int width = 160, bool patient = false}) {
  var level = [start];
  for (var d = 0; d < depth; d++) {
    final nextLevel = <_Node>[];
    for (final node in level) {
      for (var slot = 0; slot < 3; slot++) {
        final p = node.tray[slot];
        if (p == null || node.tray.indexOf(p) != slot) continue; // same piece twice: one is enough
        for (var row = 0; row <= _n - p.rows; row++) {
          for (var col = 0; col <= _n - p.cols; col++) {
            if (!node.board.canPlace(p, row, col)) continue;
            final board = Board.from(node.board);
            final clear = board.place(p, row, col);
            var points = p.size, combo = node.combo, since = node.since;
            if (clear.isEmpty) {
              if (++since >= Game.comboGrace) combo = 0;
            } else {
              combo++;
              since = 0;
              points += 10 * clear.lines * clear.lines * combo;
              if (board.isEmpty) points += 300;
            }
            var tray = [...node.tray]..[slot] = null;
            var next = node.next;
            if (tray.every((t) => t == null)) {
              if (next + 3 > draws.length) continue;
              tray = draws.sublist(next, next + 3);
              next += 3;
            }
            if (!tray.any((t) => t != null && board.canPlaceAnywhere(t))) continue;
            nextLevel.add(_Node(board, tray, node.score + points, combo, since, next, node,
                (slot: slot, row: row, col: col, lines: clear.lines, points: points),
                node.flair + (clear.lines < 2 ? 0 : 160 * (clear.lines - 1) * (clear.lines - 1))));
          }
        }
      }
    }
    nextLevel.sort((a, b) => patient ? b.patientValue.compareTo(a.patientValue) : b.value.compareTo(a.value));
    level = nextLevel.take(width).toList();
  }
  return level;
}

// ---- daily ----

/// Date of daily [number] (the inverse of [dailyNumberFor]).
DateTime dateOfDaily(int number) => DateTime.utc(2026, 10, 20).add(Duration(days: number - 1));

/// A strong opening of daily [number]: its real pieces, [length] placements from the empty board.
Map<String, dynamic> planDaily(int number, {int length = 12}) {
  final rng = Random(number * 7919 + 17); // as Game.daily
  final draws = [for (var i = 0; i < length + 6; i++) randomPiece(rng)];
  final start = _Node(Board(), draws.sublist(0, 3), 0, 0, 0, 3);
  final found = [
    for (final patient in [false, true]) ..._search(start, draws, length, width: 400, patient: patient),
  ];
  if (found.isEmpty) throw StateError('daily $number: no line of $length moves');
  // The highest score among the lines with the biggest clear.
  int most(_Node n) => n.path.map((m) => m.lines).reduce(max);
  found.sort((a, b) => most(a) != most(b) ? most(b) - most(a) : b.score.compareTo(a.score));
  final best = found.first;
  final moves = [for (final m in best.path) PlannedMove(m.slot, m.row, m.col)];
  final game = Game.daily(number);
  final tray = [for (final p in game.tray) p!.id];
  if (!_replay(game, moves) || game.score != best.score) throw StateError('daily $number: plan and game disagree');
  final top = moves.map((m) => m.points).reduce(max);
  final date = dateOfDaily(number);
  return {
    'scenario': 'daily',
    'n': number,
    'date': '${date.year}-${'${date.month}'.padLeft(2, '0')}-${'${date.day}'.padLeft(2, '0')}',
    'tray': tray,
    'score': 0,
    'moves': [for (final m in moves) m.toJson()],
    'peak': moves.indexWhere((m) => m.points == top),
  };
}
