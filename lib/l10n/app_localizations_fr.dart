// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get play => 'JOUER';

  @override
  String get continueGame => 'CONTINUER';

  @override
  String dailyTitle(int number) {
    return 'Défi #$number';
  }

  @override
  String get dailyNotPlayed => 'Les mêmes pièces pour tous aujourd’hui';

  @override
  String dailyPlayed(String score) {
    return 'Score $score · touchez pour partager';
  }

  @override
  String get instructions =>
      'Glissez les blocs sur la grille. Remplissez des lignes ou des colonnes pour les effacer.';

  @override
  String get privacyOptions => 'Options de confidentialité';

  @override
  String get rateApp => 'Noter Block Daily';

  @override
  String noAdsPrice(String price) {
    return 'Sans pub · $price';
  }

  @override
  String get restorePurchase => 'Restaurer l’achat';

  @override
  String get parentGateTitle => 'Demande à un adulte';

  @override
  String parentGateQuestion(int a, int b) {
    return 'Pour continuer, entre la réponse à $a × $b';
  }

  @override
  String get cancel => 'Annuler';

  @override
  String get continueAction => 'Continuer';

  @override
  String get updateAvailableTitle => 'Mise à jour disponible';

  @override
  String get updateAvailableBody =>
      'Une nouvelle version de Block Daily est prête.';

  @override
  String get updateLater => 'Plus tard';

  @override
  String get updateNow => 'Mettre à jour';

  @override
  String get updateRequiredTitle => 'Mise à jour requise';

  @override
  String get updateRequiredBody =>
      'Cette version de Block Daily n’est plus prise en charge. Mettez-la à jour pour continuer à jouer avec le même défi du jour que tout le monde.';

  @override
  String get updateRequiredButton => 'METTRE À JOUR';

  @override
  String get noMoreSpace => 'Plus de place';

  @override
  String get dailyComplete => 'Défi du jour terminé !';

  @override
  String get newBest => '🏆 Nouveau record !';

  @override
  String bestScore(String score) {
    return 'Record $score';
  }

  @override
  String get reviveWithAd => 'Continuer  ▶ pub';

  @override
  String get playAgain => 'Rejouer';

  @override
  String get home => 'Accueil';

  @override
  String get shareResult => 'Partager le résultat';

  @override
  String get shareScore => 'Partager le score';

  @override
  String get noAdAvailable =>
      'Aucune pub disponible pour le moment. Réessayez dans un instant.';

  @override
  String get praiseGreat => 'Bravo !';

  @override
  String get praiseAmazing => 'Génial !';

  @override
  String get praiseUnbelievable => 'Incroyable !';

  @override
  String get praisePerfect => 'PARFAIT !';

  @override
  String combo(int count) {
    return 'Combo x$count';
  }

  @override
  String get shareCopied => 'Résultat copié — collez-le où vous voulez !';

  @override
  String shareLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes',
      one: '$count ligne',
    );
    return '$_temp0';
  }

  @override
  String shareStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '📅 Série de $count jours',
      one: '📅 Série de $count jour',
    );
    return '$_temp0';
  }

  @override
  String shareNewBest(String score) {
    return '🏆 Nouveau record : $score';
  }
}
