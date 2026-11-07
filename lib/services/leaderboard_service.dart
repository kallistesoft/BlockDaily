import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// One score on a board; [mine] marks the player's own entry.
class Entry {
  const Entry(this.score, {this.mine = false});

  final int score;
  final bool mine;
}

/// Top scores of all players (no names), shown on the home screen.
class Leaderboards {
  const Leaderboards({required this.classicToday, required this.classicAll, required this.dailyToday});

  static const size = 3;

  final List<Entry> classicToday;
  final List<Entry> classicAll;
  final List<Entry> dailyToday;

  /// Best first, at most [size] entries, the player's own one marked.
  static List<Entry> rank(Map<String, int> scores, String? me) {
    final ids = scores.keys.toList()..sort((a, b) => scores[b]!.compareTo(scores[a]!));
    return [for (final id in ids.take(size)) Entry(scores[id]!, mine: id == me)];
  }

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

/// Sends finished games to the shared boards and reads the top scores.
/// Best effort: never throws; boards are simply missing offline.
abstract class LeaderboardService {
  /// A finished classic game, played on daily number [day]; also the all-time board.
  Future<void> submitClassic(int score, int day);

  /// The player's all-time best, sent at launch so scores from before the boards (or offline) count too.
  Future<void> submitBest(int score);

  /// The single daily attempt of daily number [day].
  Future<void> submitDaily(int score, int day);

  /// Today's boards for daily number [day]; null when they can't be read.
  Future<Leaderboards?> load(int day);
}

/// Web and tests: no boards.
class NoLeaderboardService implements LeaderboardService {
  const NoLeaderboardService();

  @override
  Future<void> submitClassic(int score, int day) async {}

  @override
  Future<void> submitBest(int score) async {}

  @override
  Future<void> submitDaily(int score, int day) async {}

  @override
  Future<Leaderboards?> load(int day) async => null;
}

/// Cloud Firestore (project block-daily-b71d6), one document per anonymous player per board.
/// The security rules (firestore.rules) only let a classic score go up and a daily score be written once,
/// so a lower score is simply rejected.
class FirestoreLeaderboardService implements LeaderboardService {
  final _db = FirebaseFirestore.instance;

  Future<String?> _uid() async {
    try {
      final auth = FirebaseAuth.instance;
      return auth.currentUser?.uid ?? (await auth.signInAnonymously()).user?.uid;
    } catch (e) {
      debugPrint('leaderboard sign-in: $e');
      return null; // offline on the very first launch: try again next game
    }
  }

  CollectionReference<Map<String, dynamic>> get _classicAll => _db.collection('classic_all');
  CollectionReference<Map<String, dynamic>> _classicDay(int day) =>
      _db.collection('classic_day').doc('$day').collection('scores');
  CollectionReference<Map<String, dynamic>> _dailyDay(int day) =>
      _db.collection('daily_day').doc('$day').collection('scores');

  /// Not awaited: offline, Firestore queues the write until the network is back.
  void _write(DocumentReference<Map<String, dynamic>> doc, int score) {
    doc.set({'score': score}).catchError((_) {}); // rejected: not better than the stored score
  }

  @override
  Future<void> submitClassic(int score, int day) async {
    if (score <= 0) return;
    final uid = await _uid();
    if (uid == null) return;
    _write(_classicAll.doc(uid), score);
    _write(_classicDay(day).doc(uid), score);
  }

  @override
  Future<void> submitBest(int score) async {
    if (score <= 0) return;
    final uid = await _uid();
    if (uid != null) _write(_classicAll.doc(uid), score);
  }

  @override
  Future<void> submitDaily(int score, int day) async {
    final uid = await _uid();
    if (uid == null) return;
    _write(_dailyDay(day).doc(uid), score);
  }

  @override
  Future<Leaderboards?> load(int day) async {
    try {
      final uid = await _uid();
      Future<List<Entry>> top(CollectionReference<Map<String, dynamic>> board) async {
        final snap = await board.orderBy('score', descending: true).limit(Leaderboards.size).get();
        return Leaderboards.rank({for (final d in snap.docs) d.id: d.data()['score'] as int}, uid);
      }

      final boards = await Future.wait([top(_classicDay(day)), top(_classicAll), top(_dailyDay(day))])
          .timeout(const Duration(seconds: 8));
      return Leaderboards(classicToday: boards[0], classicAll: boards[1], dailyToday: boards[2]);
    } catch (e) {
      debugPrint('leaderboard load: $e');
      return null;
    }
  }
}
