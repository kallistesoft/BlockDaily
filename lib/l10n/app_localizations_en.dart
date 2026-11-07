// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get play => 'PLAY';

  @override
  String get continueGame => 'CONTINUE';

  @override
  String dailyTitle(int number) {
    return 'Daily #$number';
  }

  @override
  String get dailyNotPlayed => 'Same pieces for everyone today';

  @override
  String dailyPlayed(String score) {
    return 'Score $score · tap to share';
  }

  @override
  String get instructions =>
      'Drag blocks onto the board. Fill rows or columns to clear them.';

  @override
  String get privacyOptions => 'Privacy options';

  @override
  String get rateApp => 'Rate Block Daily';

  @override
  String get leaderToday => 'TODAY';

  @override
  String get leaderAllTime => 'ALL TIME';

  @override
  String get leaderDaily => 'DAILY';

  @override
  String noAdsPrice(String price) {
    return 'No ads · $price';
  }

  @override
  String get restorePurchase => 'Restore purchase';

  @override
  String get parentGateTitle => 'Ask a grown-up';

  @override
  String parentGateQuestion(int a, int b) {
    return 'To continue, enter the answer to $a × $b';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get continueAction => 'Continue';

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String get updateAvailableBody => 'A new version of Block Daily is ready.';

  @override
  String get updateLater => 'Later';

  @override
  String get updateNow => 'Update';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String get updateRequiredBody =>
      'This version of Block Daily is no longer supported. Update to keep playing, so your daily puzzle matches everyone else\'s.';

  @override
  String get updateRequiredButton => 'UPDATE';

  @override
  String get noMoreSpace => 'No more space';

  @override
  String get dailyComplete => 'Daily complete!';

  @override
  String get newBest => '🏆 New best!';

  @override
  String bestScore(String score) {
    return 'Best $score';
  }

  @override
  String get reviveWithAd => 'Continue  ▶ ad';

  @override
  String get playAgain => 'Play again';

  @override
  String get home => 'Home';

  @override
  String get shareResult => 'Share result';

  @override
  String get shareScore => 'Share score';

  @override
  String get noAdAvailable =>
      'No ad available right now. Try again in a moment.';

  @override
  String get praiseGreat => 'Great!';

  @override
  String get praiseAmazing => 'Amazing!';

  @override
  String get praiseUnbelievable => 'Unbelievable!';

  @override
  String get praisePerfect => 'PERFECT!';

  @override
  String combo(int count) {
    return 'Combo x$count';
  }

  @override
  String get shareCopied => 'Result copied — paste it anywhere!';

  @override
  String shareLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '$count line',
    );
    return '$_temp0';
  }

  @override
  String shareStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '📅 $count-day streak',
      one: '📅 $count-day streak',
    );
    return '$_temp0';
  }

  @override
  String shareNewBest(String score) {
    return '🏆 New best: $score';
  }
}
