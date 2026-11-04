import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Result of a finished daily puzzle.
class DailyResult {
  const DailyResult({required this.number, required this.score, required this.bestCombo, required this.lines});

  final int number;
  final int score;
  final int bestCombo;
  final int lines;

  String encode() => '$score,$bestCombo,$lines';

  static DailyResult? decode(int number, String? raw) {
    final parts = raw?.split(',');
    if (parts == null || parts.length != 3) return null;
    return DailyResult(
      number: number,
      score: int.parse(parts[0]),
      bestCombo: int.parse(parts[1]),
      lines: int.parse(parts[2]),
    );
  }
}

class StatsStore {
  StatsStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<StatsStore> open() async => StatsStore(await SharedPreferences.getInstance());

  int get bestScore => _prefs.getInt('best') ?? 0;
  int get gamesPlayed => _prefs.getInt('games') ?? 0;

  /// Records a finished classic game; returns true for a new best score.
  Future<bool> recordClassic(int score) async {
    await _prefs.setInt('games', gamesPlayed + 1);
    if (score <= bestScore) return false;
    await _prefs.setInt('best', score);
    return true;
  }

  DailyResult? daily(int number) => DailyResult.decode(number, _prefs.getString('daily.$number'));

  /// One attempt per day: the first result is kept.
  Future<void> recordDaily(DailyResult result) async {
    if (daily(result.number) != null) return;
    await _prefs.setString('daily.${result.number}', result.encode());
  }

  /// Consecutive days with a finished daily, ending today (or yesterday if today isn't played yet).
  int dailyStreak(int today) {
    var day = daily(today) != null ? today : today - 1;
    var streak = 0;
    while (day > 0 && daily(day) != null) {
      streak++;
      day--;
    }
    return streak;
  }

  /// First launch on this device; stored on the first call.
  DateTime firstLaunch() {
    final ms = _prefs.getInt('firstLaunch');
    if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    _prefs.setInt('firstLaunch', now.millisecondsSinceEpoch);
    return now;
  }

  /// "Remove Ads" bought; cached so it holds offline.
  bool get premium => _prefs.getBool('premium') ?? false;
  Future<void> setPremium(bool value) => _prefs.setBool('premium', value);

  /// The player tapped the "rate" button; the button and the rating prompt stay hidden afterwards.
  bool get reviewed => _prefs.getBool('reviewed') ?? false;
  Future<void> setReviewed(bool value) => _prefs.setBool('reviewed', value);

  /// Last time the in-app rating dialog was requested.
  DateTime? get reviewPromptedAt {
    final ms = _prefs.getInt('reviewPromptedAt');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setReviewPromptedAt(DateTime time) => _prefs.setInt('reviewPromptedAt', time.millisecondsSinceEpoch);

  bool get muted => _prefs.getBool('muted') ?? false;
  Future<void> setMuted(bool value) => _prefs.setBool('muted', value);

  // Game in progress, one slot per mode ('classic' / 'daily').
  Map<String, dynamic>? savedGame(String mode) {
    final raw = _prefs.getString('save.$mode');
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveGame(String mode, Map<String, dynamic> json) => _prefs.setString('save.$mode', jsonEncode(json));
  Future<void> clearGame(String mode) => _prefs.remove('save.$mode');
}
