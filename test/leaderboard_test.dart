import 'package:block_daily/services/leaderboard_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Boards held in memory; records what the game submits.
class FakeLeaderboard implements LeaderboardService {
  FakeLeaderboard([Leaderboards? boards]) : _boards = ValueNotifier(boards);

  final ValueNotifier<Leaderboards?> _boards;
  final classic = <(int, int)>[];
  final daily = <(int, int)>[];
  final best = <int>[];
  final loads = <int>[];

  @override
  ValueListenable<Leaderboards?> get boards => _boards;

  @override
  Future<void> load(int day) async => loads.add(day);

  @override
  Future<void> submitClassic(int score, int day) async => classic.add((score, day));

  @override
  Future<void> submitBest(int score) async => best.add(score);

  @override
  Future<void> submitDaily(int score, int day) async => daily.add((score, day));
}

/// Firestore stand-in: scores by board and player, counting reads and writes.
class FakeBackend implements LeaderboardBackend {
  final scores = {for (final b in Leaderboard.values) b: <String, int>{}};
  String? me = 'me';
  int reads = 0;
  final writes = <(Leaderboard, int)>[];
  bool offline = false;

  @override
  Future<String?> uid() async => me;

  @override
  Future<Map<String, int>> top(Leaderboard board, int day) async {
    if (offline) throw Exception('offline');
    reads++;
    return Map.of(scores[board]!);
  }

  @override
  void write(Leaderboard board, int day, String uid, int score) {
    writes.add((board, score));
    scores[board]![uid] = score;
  }
}

void main() {
  test('rank keeps the 3 best, best first, and marks the player', () {
    final board = Leaderboards.rank({'a': 50, 'me': 700, 'b': 900, 'c': 10}, 'me');
    expect(board.map((e) => e.score), [900, 700, 50]);
    expect(board.map((e) => e.mine), [false, true, false]);
    expect(Leaderboards.place(board), 1);
  });

  test('outside the top 3 there is no place', () {
    final board = Leaderboards.rank({'a': 50, 'b': 60, 'c': 70, 'me': 1}, 'me');
    expect(board, hasLength(3));
    expect(Leaderboards.place(board), isNull);
    expect(Leaderboards.place(Leaderboards.rank({}, 'me')), isNull);
  });

  test('a score qualifies when it beats the 3rd score, fills a short board or raises my own entry', () {
    const full = [Entry(900), Entry(500), Entry(100)];
    expect(Leaderboards.qualifies(full, 100), isFalse);
    expect(Leaderboards.qualifies(full, 101), isTrue);
    expect(Leaderboards.qualifies(const [Entry(900)], 1), isTrue);
    expect(Leaderboards.qualifies(const [], 0), isFalse);
    const mine = [Entry(900), Entry(500, mine: true)];
    expect(Leaderboards.qualifies(mine, 400), isFalse);
    expect(Leaderboards.qualifies(mine, 600), isTrue);
  });

  test('insert replaces my entry and keeps the top 3', () {
    final board = Leaderboards.insert(const [Entry(900), Entry(500, mine: true), Entry(100)], 1000);
    expect(board.map((e) => (e.score, e.mine)), [(1000, true), (900, false), (100, false)]);
  });

  test('home medal is the best classic place, today or all time', () {
    const boards = Leaderboards(
      classicToday: [Entry(500, mine: true)],
      classicAll: [Entry(900), Entry(800), Entry(500, mine: true)],
      dailyToday: [],
    );
    expect(boards.classicPlace, 0);
    const none = Leaderboards(classicToday: [Entry(1)], classicAll: [], dailyToday: [Entry(5, mine: true)]);
    expect(none.classicPlace, isNull, reason: 'the daily board has no home medal');
  });

  group('CachedLeaderboardService', () {
    late FakeBackend backend;
    late CachedLeaderboardService service;

    setUp(() {
      backend = FakeBackend();
      service = CachedLeaderboardService(backend);
      for (final b in [Leaderboard.classicToday, Leaderboard.classicAll]) {
        backend.scores[b]!.addAll({'a': 900, 'b': 500, 'c': 300});
      }
    });

    test('loads once per day', () async {
      await service.load(19);
      await service.load(19);
      expect(backend.reads, 3, reason: 'one query per board');
      expect(service.boards.value!.classicAll.map((e) => e.score), [900, 500, 300]);
      await service.load(20);
      expect(backend.reads, 6);
    });

    test('a score below the cached top 3 costs no read and no write', () async {
      await service.load(19);
      await service.submitClassic(200, 19);
      expect(backend.reads, 3);
      expect(backend.writes, isEmpty);
    });

    test('a score beating the cached board is checked again, then posted', () async {
      await service.load(19);
      await service.submitClassic(600, 19);
      expect(backend.reads, 5, reason: 'one fresh read per board it beats');
      expect(backend.writes, [(Leaderboard.classicToday, 600), (Leaderboard.classicAll, 600)]);
      final boards = service.boards.value!;
      expect(boards.classicAll.map((e) => (e.score, e.mine)), [(900, false), (600, true), (500, false)]);
      expect(boards.classicPlace, 1);
    });

    test('not posted when others got there first', () async {
      await service.load(19);
      backend.scores[Leaderboard.classicAll]!.addAll({'d': 2000, 'e': 1500, 'f': 1000});
      await service.submitClassic(600, 19);
      expect(backend.writes, [(Leaderboard.classicToday, 600)]);
      expect(service.boards.value!.classicAll.map((e) => e.score), [2000, 1500, 1000], reason: 'cache refreshed');
    });

    test('daily: first score of the day makes the board', () async {
      await service.load(19);
      await service.submitDaily(42, 19);
      expect(backend.writes, [(Leaderboard.dailyToday, 42)]);
      expect(service.boards.value!.dailyToday.single.mine, isTrue);
    });

    test('the best score from before the boards is posted at launch', () async {
      await service.load(19);
      await service.submitBest(5000);
      expect(backend.writes, [(Leaderboard.classicAll, 5000)]);
      await service.submitBest(5000);
      expect(backend.writes, hasLength(1), reason: 'already on the board: nothing to do');
    });

    test('offline at launch: no boards, checked fresh on the next game, load retried', () async {
      backend.offline = true;
      await service.load(19);
      expect(service.boards.value, isNull);
      await service.submitClassic(600, 19);
      expect(backend.writes, isEmpty);
      backend.offline = false;
      await service.load(19);
      expect(service.boards.value, isNotNull);
    });
  });
}
