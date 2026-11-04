import 'package:block_daily/services/review_service.dart';
import 'package:block_daily/services/stats_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeReview implements ReviewService {
  int requests = 0;
  int listings = 0;
  @override
  Future<void> requestReview() async => requests++;
  @override
  Future<void> openStoreListing() async => listings++;
}

void main() {
  late StatsStore stats;
  late FakeReview review;
  var now = DateTime(2026, 11, 4);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    stats = await StatsStore.open();
    review = FakeReview();
    now = DateTime(2026, 11, 4);
  });

  ReviewPrompter prompter() => ReviewPrompter(stats, review, now: () => now);

  test('no prompt during the first games, which are always a new best', () async {
    for (var i = 1; i < ReviewPrompter.minGames; i++) {
      await stats.recordClassic(i * 100);
      await prompter().onNewBest();
      expect(review.requests, 0, reason: 'game $i');
    }
    await stats.recordClassic(1000);
    await prompter().onNewBest();
    expect(review.requests, 1);
    expect(stats.reviewPromptedAt, now);
  });

  test('one prompt per cooldown', () async {
    for (var i = 0; i < ReviewPrompter.minGames; i++) {
      await stats.recordClassic(i);
    }
    await prompter().onNewBest();
    now = now.add(const Duration(days: 13));
    await prompter().onNewBest();
    expect(review.requests, 1);
    now = now.add(const Duration(days: 1));
    await prompter().onNewBest();
    expect(review.requests, 2);
  });

  test('never again once the player tapped the rate button', () async {
    for (var i = 0; i < ReviewPrompter.minGames; i++) {
      await stats.recordClassic(i);
    }
    await stats.setReviewed(true);
    expect(prompter().shouldPrompt, isFalse);
    await prompter().onNewBest();
    expect(review.requests, 0);
  });
}
