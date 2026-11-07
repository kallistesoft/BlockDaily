import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// Home: main button starting a classic game
  ///
  /// In en, this message translates to:
  /// **'PLAY'**
  String get play;

  /// Home: main button when a classic game is saved
  ///
  /// In en, this message translates to:
  /// **'CONTINUE'**
  String get continueGame;

  /// Daily puzzle name, on the home card and the game screen
  ///
  /// In en, this message translates to:
  /// **'Daily #{number}'**
  String dailyTitle(int number);

  /// Home daily card subtitle before playing
  ///
  /// In en, this message translates to:
  /// **'Same pieces for everyone today'**
  String get dailyNotPlayed;

  /// Home daily card subtitle once played; score is already formatted
  ///
  /// In en, this message translates to:
  /// **'Score {score} · tap to share'**
  String dailyPlayed(String score);

  /// Home: how to play
  ///
  /// In en, this message translates to:
  /// **'Drag blocks onto the board. Fill rows or columns to clear them.'**
  String get instructions;

  /// Home: opens the ad consent form
  ///
  /// In en, this message translates to:
  /// **'Privacy options'**
  String get privacyOptions;

  /// Home: opens the store page to leave a review; hidden once tapped
  ///
  /// In en, this message translates to:
  /// **'Rate Block Daily'**
  String get rateApp;

  /// Home leaderboard column: top 3 classic scores of all players today
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get leaderToday;

  /// Home leaderboard column: top 3 classic scores of all players ever
  ///
  /// In en, this message translates to:
  /// **'ALL TIME'**
  String get leaderAllTime;

  /// Home leaderboard column: top 3 scores of all players on today's daily puzzle
  ///
  /// In en, this message translates to:
  /// **'DAILY'**
  String get leaderDaily;

  /// Remove ads purchase button; price comes localized from the store
  ///
  /// In en, this message translates to:
  /// **'No ads · {price}'**
  String noAdsPrice(String price);

  /// No description provided for @restorePurchase.
  ///
  /// In en, this message translates to:
  /// **'Restore purchase'**
  String get restorePurchase;

  /// Parental gate before a purchase; addresses a child
  ///
  /// In en, this message translates to:
  /// **'Ask a grown-up'**
  String get parentGateTitle;

  /// Parental gate multiplication; addresses a child
  ///
  /// In en, this message translates to:
  /// **'To continue, enter the answer to {a} × {b}'**
  String parentGateQuestion(int a, int b);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Dialog confirm button
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'A new version of Block Daily is ready.'**
  String get updateAvailableBody;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateNow;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'This version of Block Daily is no longer supported. Update to keep playing, so your daily puzzle matches everyone else\'s.'**
  String get updateRequiredBody;

  /// No description provided for @updateRequiredButton.
  ///
  /// In en, this message translates to:
  /// **'UPDATE'**
  String get updateRequiredButton;

  /// Classic game over title
  ///
  /// In en, this message translates to:
  /// **'No more space'**
  String get noMoreSpace;

  /// Daily game over title
  ///
  /// In en, this message translates to:
  /// **'Daily complete!'**
  String get dailyComplete;

  /// No description provided for @newBest.
  ///
  /// In en, this message translates to:
  /// **'🏆 New best!'**
  String get newBest;

  /// Game over: best classic score; score is already formatted
  ///
  /// In en, this message translates to:
  /// **'Best {score}'**
  String bestScore(String score);

  /// Game over: continue after watching a rewarded ad
  ///
  /// In en, this message translates to:
  /// **'Continue  ▶ ad'**
  String get reviveWithAd;

  /// No description provided for @playAgain.
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get playAgain;

  /// Game over: back to the home screen
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Daily game over share button
  ///
  /// In en, this message translates to:
  /// **'Share result'**
  String get shareResult;

  /// Classic game over share button
  ///
  /// In en, this message translates to:
  /// **'Share score'**
  String get shareScore;

  /// No description provided for @noAdAvailable.
  ///
  /// In en, this message translates to:
  /// **'No ad available right now. Try again in a moment.'**
  String get noAdAvailable;

  /// Callout for clearing 2 lines at once
  ///
  /// In en, this message translates to:
  /// **'Great!'**
  String get praiseGreat;

  /// Callout for clearing 3 lines at once
  ///
  /// In en, this message translates to:
  /// **'Amazing!'**
  String get praiseAmazing;

  /// Callout for clearing 4+ lines at once
  ///
  /// In en, this message translates to:
  /// **'Unbelievable!'**
  String get praiseUnbelievable;

  /// Callout for clearing the whole board
  ///
  /// In en, this message translates to:
  /// **'PERFECT!'**
  String get praisePerfect;

  /// Consecutive clears counter
  ///
  /// In en, this message translates to:
  /// **'Combo x{count}'**
  String combo(int count);

  /// Snackbar when sharing falls back to the clipboard
  ///
  /// In en, this message translates to:
  /// **'Result copied — paste it anywhere!'**
  String get shareCopied;

  /// Shared text: lines cleared in the daily
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} line} other{{count} lines}}'**
  String shareLines(int count);

  /// Shared text: consecutive days played
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{📅 {count}-day streak} other{📅 {count}-day streak}}'**
  String shareStreak(int count);

  /// Shared text after a classic record; score is already formatted
  ///
  /// In en, this message translates to:
  /// **'🏆 New best: {score}'**
  String shareNewBest(String score);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
