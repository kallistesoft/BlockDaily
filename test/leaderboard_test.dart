import 'package:block_daily/services/leaderboard_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Boards held in memory; records what the game submits.
class FakeLeaderboard implements LeaderboardService {
  FakeLeaderboard([this.boards]);

  Leaderboards? boards;
  final classic = <(int, int)>[];
  final daily = <(int, int)>[];
  final best = <int>[];

  @override
  Future<void> submitClassic(int score, int day) async => classic.add((score, day));

  @override
  Future<void> submitBest(int score) async => best.add(score);

  @override
  Future<void> submitDaily(int score, int day) async => daily.add((score, day));

  @override
  Future<Leaderboards?> load(int day) async => boards;
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
}
