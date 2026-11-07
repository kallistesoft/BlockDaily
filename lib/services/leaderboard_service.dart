import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// One score on a board; [mine] marks the player's own entry.
class Entry {
  const Entry(this.score, {this.mine = false});

  final int score;
  final bool mine;
}

enum Leaderboard { classicToday, classicAll, dailyToday }

/// Top scores of all players (no names), shown on the home screen.
class Leaderboards {
  const Leaderboards({required this.classicToday, required this.classicAll, required this.dailyToday});

  static const size = 3;

  final List<Entry> classicToday;
  final List<Entry> classicAll;
  final List<Entry> dailyToday;

  List<Entry> of(Leaderboard board) => switch (board) {
        Leaderboard.classicToday => classicToday,
        Leaderboard.classicAll => classicAll,
        Leaderboard.dailyToday => dailyToday,
      };

  Leaderboards replace(Leaderboard board, List<Entry> entries) => Leaderboards(
        classicToday: board == Leaderboard.classicToday ? entries : classicToday,
        classicAll: board == Leaderboard.classicAll ? entries : classicAll,
        dailyToday: board == Leaderboard.dailyToday ? entries : dailyToday,
      );

  /// Best first, at most [size] entries, the player's own one marked.
  static List<Entry> rank(Map<String, int> scores, String? me) {
    final ids = scores.keys.toList()..sort((a, b) => scores[b]!.compareTo(scores[a]!));
    return [for (final id in ids.take(size)) Entry(scores[id]!, mine: id == me)];
  }

  /// Whether [score] would enter [board] (or raise the player's own entry on it).
  static bool qualifies(List<Entry> board, int score) {
    if (score <= 0) return false;
    final mine = board.where((e) => e.mine).firstOrNull;
    if (mine != null) return score > mine.score;
    return board.length < size || score > board.last.score;
  }

  /// [board] with the player's entry set to [score].
  static List<Entry> insert(List<Entry> board, int score) =>
      ([for (final e in board) if (!e.mine) e, Entry(score, mine: true)]..sort((a, b) => b.score.compareTo(a.score)))
          .take(size)
          .toList();

  /// The player's place (0 = first) on [board], or null outside the top.
  static int? place(List<Entry> board) {
    final i = board.indexWhere((e) => e.mine);
    return i < 0 ? null : i;
  }

  /// Best classic place, today or all time: the medal next to the home best score.
  int? get classicPlace {
    final places = [place(classicToday), place(classicAll)].whereType<int>();
    return places.isEmpty ? null : places.reduce((a, b) => a < b ? a : b);
  }
}

/// Shared boards, read once at launch to keep Firestore reads low.
/// Best effort: never throws; boards are simply missing offline.
abstract class LeaderboardService {
  /// The boards as fetched at launch, updated with the player's own posts; null until loaded or offline.
  ValueListenable<Leaderboards?> get boards;

  /// Fetches the boards of daily number [day]; does nothing if they're already loaded for that day.
  Future<void> load(int day);

  /// A finished classic game, played on daily number [day]: today's board and the all-time board.
  Future<void> submitClassic(int score, int day);

  /// The player's all-time best, checked at launch so scores from before the boards count too.
  Future<void> submitBest(int score);

  /// The single daily attempt of daily number [day].
  Future<void> submitDaily(int score, int day);
}

/// Web and tests: no boards.
class NoLeaderboardService implements LeaderboardService {
  const NoLeaderboardService();

  static final _none = ValueNotifier<Leaderboards?>(null);

  @override
  ValueListenable<Leaderboards?> get boards => _none;

  @override
  Future<void> load(int day) async {}

  @override
  Future<void> submitClassic(int score, int day) async {}

  @override
  Future<void> submitBest(int score) async {}

  @override
  Future<void> submitDaily(int score, int day) async {}
}

/// Where the boards live: Firestore in the app, a fake in tests.
abstract class LeaderboardBackend {
  /// The anonymous player id; null when sign-in fails (offline on the first launch).
  Future<String?> uid();

  /// Top scores of [board] by player id.
  Future<Map<String, int>> top(Leaderboard board, int day);

  /// Stores the player's score; not awaited, so offline the write waits for the network.
  void write(Leaderboard board, int day, String uid, int score);
}

/// Keeps the boards fetched at launch and only posts a score that still makes a top 3:
/// a score that beats the cached board triggers one fresh read of that board, then a write if it still qualifies.
class CachedLeaderboardService implements LeaderboardService {
  CachedLeaderboardService(this._backend);

  final LeaderboardBackend _backend;
  final _boards = ValueNotifier<Leaderboards?>(null);
  int? _day;
  Future<void>? _loading;

  static const _timeout = Duration(seconds: 8);

  @override
  ValueListenable<Leaderboards?> get boards => _boards;

  @override
  Future<void> load(int day) {
    if (_day != day) {
      _day = day;
      _loading = null;
    }
    return _loading ??= _fetchAll(day);
  }

  Future<void> _fetchAll(int day) async {
    try {
      final uid = await _backend.uid();
      final tops = await Future.wait([for (final b in Leaderboard.values) _backend.top(b, day)]).timeout(_timeout);
      if (_day != day) return;
      _boards.value = Leaderboards(
        classicToday: Leaderboards.rank(tops[0], uid),
        classicAll: Leaderboards.rank(tops[1], uid),
        dailyToday: Leaderboards.rank(tops[2], uid),
      );
    } catch (e) {
      debugPrint('leaderboard load: $e');
      if (_day == day) _loading = null; // offline: try again after the next game
    }
  }

  @override
  Future<void> submitClassic(int score, int day) async {
    await Future.wait([_submit(Leaderboard.classicToday, day, score), _submit(Leaderboard.classicAll, day, score)]);
  }

  @override
  Future<void> submitBest(int score) => _submit(Leaderboard.classicAll, _day ?? 0, score);

  @override
  Future<void> submitDaily(int score, int day) => _submit(Leaderboard.dailyToday, day, score);

  /// The cached board, if it's the one [day] would post to.
  List<Entry>? _cached(Leaderboard board, int day) =>
      board == Leaderboard.classicAll || day == _day ? _boards.value?.of(board) : null;

  Future<void> _submit(Leaderboard board, int day, int score) async {
    if (score <= 0) return;
    final cached = _cached(board, day);
    if (cached != null && !Leaderboards.qualifies(cached, score)) return; // no read, no write
    try {
      final uid = await _backend.uid();
      if (uid == null) return;
      final fresh = Leaderboards.rank(await _backend.top(board, day).timeout(_timeout), uid);
      if (!Leaderboards.qualifies(fresh, score)) {
        _update(board, day, fresh);
        return;
      }
      _backend.write(board, day, uid, score);
      _update(board, day, Leaderboards.insert(fresh, score));
    } catch (e) {
      debugPrint('leaderboard submit: $e');
    }
  }

  void _update(Leaderboard board, int day, List<Entry> entries) {
    final current = _boards.value;
    if (current != null && (board == Leaderboard.classicAll || day == _day)) _boards.value = current.replace(board, entries);
  }
}

/// Cloud Firestore (project block-daily-b71d6), one document per anonymous player per board.
/// The security rules (firestore.rules) only let a classic score go up and a daily score be written once,
/// and App Check limits access to the genuine app.
class FirestoreLeaderboardBackend implements LeaderboardBackend {
  final _db = FirebaseFirestore.instance;

  @override
  Future<String?> uid() async {
    try {
      final auth = FirebaseAuth.instance;
      return auth.currentUser?.uid ?? (await auth.signInAnonymously()).user?.uid;
    } catch (e) {
      debugPrint('leaderboard sign-in: $e');
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>> _collection(Leaderboard board, int day) => switch (board) {
        Leaderboard.classicAll => _db.collection('classic_all'),
        Leaderboard.classicToday => _db.collection('classic_day').doc('$day').collection('scores'),
        Leaderboard.dailyToday => _db.collection('daily_day').doc('$day').collection('scores'),
      };

  @override
  Future<Map<String, int>> top(Leaderboard board, int day) async {
    final snap = await _collection(board, day)
        .orderBy('score', descending: true)
        .limit(Leaderboards.size)
        .get(const GetOptions(source: Source.server));
    return {for (final d in snap.docs) d.id: d.data()['score'] as int};
  }

  @override
  void write(Leaderboard board, int day, String uid, int score) {
    _collection(board, day).doc(uid).set({'score': score}).catchError((Object e) {
      debugPrint('leaderboard write: $e'); // rejected by the rules or App Check
    });
  }
}

/// App Check: Firestore only answers the genuine app (Play Integrity on Android, App Attest on iOS), so scripts can't
/// post scores.
/// Debug builds use the debug provider; pass `--dart-define=APP_CHECK_DEBUG_TOKEN=<token registered in the console>`,
/// or read the token the SDK logs on first run and register it.
Future<void> initAppCheck() => FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? AndroidDebugProvider(debugToken: _debugToken.isEmpty ? null : _debugToken)
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? AppleDebugProvider(debugToken: _debugToken.isEmpty ? null : _debugToken)
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );

const _debugToken = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');
