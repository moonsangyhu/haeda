import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haeda/features/my_page/models/challenge_summary.dart';
import 'package:haeda/features/my_page/providers/my_challenges_provider.dart';
import 'package:haeda/features/status_bar/providers/most_recent_challenge_provider.dart';

ChallengeSummary _summary(String id, String icon) => ChallengeSummary(
      id: id,
      title: 'title-$id',
      category: 'cat',
      startDate: '2026-04-01',
      endDate: '2026-05-01',
      status: 'active',
      memberCount: 1,
      achievementRate: 0.0,
      icon: icon,
    );

void main() {
  group('mostRecentChallengeProvider', () {
    test('returns null when myChallenges is empty', () async {
      final container = ProviderContainer(overrides: [
        myChallengesProvider
            .overrideWith((ref) async => const <ChallengeSummary>[]),
      ]);
      addTearDown(container.dispose);

      await container.read(myChallengesProvider.future);
      expect(container.read(mostRecentChallengeProvider), isNull);
    });

    test('returns first item (server already sorted)', () async {
      final container = ProviderContainer(overrides: [
        myChallengesProvider.overrideWith((ref) async => [
              _summary('a', '🏃'),
              _summary('b', '📚'),
            ]),
      ]);
      addTearDown(container.dispose);

      await container.read(myChallengesProvider.future);
      final first = container.read(mostRecentChallengeProvider);
      expect(first?.id, 'a');
      expect(first?.icon, '🏃');
    });
  });
}
