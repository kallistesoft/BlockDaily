import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

import 'share_text.dart';
import 'stats_store.dart';

/// Asks players to rate the game.
abstract class ReviewService {
  /// Google's native in-app rating dialog, when the store allows it (it has its own quota).
  /// Best effort: never throws, never tells whether the dialog was shown.
  Future<void> requestReview();

  /// The store listing, where the player can write a review.
  Future<void> openStoreListing();
}

/// Web and tests: nothing to rate.
class NoReviewService implements ReviewService {
  const NoReviewService();

  @override
  Future<void> requestReview() async {}

  @override
  Future<void> openStoreListing() async {}
}

/// Google Play (and the App Store later) through the `in_app_review` plugin.
class StoreReviewService implements ReviewService {
  final _review = InAppReview.instance;

  @override
  Future<void> requestReview() async {
    try {
      if (await _review.isAvailable()) await _review.requestReview();
    } catch (_) {
      // Not installed from Play (test builds) or Play unavailable: silently skip.
    }
  }

  @override
  Future<void> openStoreListing() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _review.openStoreListing();
        return;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS && appStoreId.isNotEmpty) {
        await _review.openStoreListing(appStoreId: appStoreId);
        return;
      }
    } catch (_) {
      // Fall through to the web store page.
    }
    await launchUrl(Uri.parse(storeUrl), mode: LaunchMode.externalApplication);
  }
}

/// Decides when a new best score is worth the in-app rating prompt.
///
/// The first games always set a new best, so the player must have a few games behind them; after that
/// at most one prompt per [cooldown], and none once the player has tapped the rate button.
class ReviewPrompter {
  const ReviewPrompter(this.stats, this.review, {this.now = DateTime.now});

  final StatsStore stats;
  final ReviewService review;
  final DateTime Function() now;

  static const minGames = 3;
  static const cooldown = Duration(days: 14);

  bool get shouldPrompt {
    if (stats.reviewed || stats.gamesPlayed < minGames) return false;
    final last = stats.reviewPromptedAt;
    return last == null || now().difference(last) >= cooldown;
  }

  /// Call after a new best score; shows the prompt when [shouldPrompt] and records the attempt.
  Future<void> onNewBest() async {
    if (!shouldPrompt) return;
    await stats.setReviewPromptedAt(now());
    await review.requestReview();
  }
}
