import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haeda/features/my_page/models/challenge_summary.dart';
import 'package:haeda/features/my_page/widgets/challenge_card.dart';

void main() {
  group('ChallengeCard', () {
    testWidgets('displays title, achievement rate, and member count', (tester) async {
      final challenge = ChallengeSummary(
        id: 'test-id',
        title: '운동 30일',
        category: '운동',
        startDate: '2026-04-01',
        endDate: '2026-04-30',
        status: 'active',
        memberCount: 5,
        achievementRate: 73.3,
        badge: null,
      );

      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChallengeCard(
              challenge: challenge,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('운동 30일'), findsOneWidget);
      expect(find.textContaining('73.3%'), findsOneWidget);
      expect(find.textContaining('5명'), findsOneWidget);
      expect(find.text('운동'), findsOneWidget);

      await tester.tap(find.byType(ChallengeCard));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
