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

    testWidgets('completed challenge shows (완료) suffix on title',
        (tester) async {
      final challenge = ChallengeSummary(
        id: 'test-id',
        title: '물 마시기',
        category: '건강',
        startDate: '2026-03-01',
        endDate: '2026-03-31',
        status: 'completed',
        memberCount: 3,
        achievementRate: 90.0,
        badge: 'completed',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChallengeCard(challenge: challenge, onTap: () {}),
          ),
        ),
      );

      expect(find.text('물 마시기 (완료)'), findsOneWidget);
    });

    testWidgets('active challenge does not show (완료) suffix',
        (tester) async {
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

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChallengeCard(challenge: challenge, onTap: () {}),
          ),
        ),
      );

      expect(find.text('운동 30일'), findsOneWidget);
      expect(find.text('운동 30일 (완료)'), findsNothing);
    });

    testWidgets('completed challenge with badge shows 배지 획득 label',
        (tester) async {
      final challenge = ChallengeSummary(
        id: 'test-id',
        title: '물 마시기',
        category: '건강',
        startDate: '2026-03-01',
        endDate: '2026-03-31',
        status: 'completed',
        memberCount: 3,
        achievementRate: 90.0,
        badge: 'completed',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChallengeCard(challenge: challenge, onTap: () {}),
          ),
        ),
      );

      expect(find.text('배지 획득'), findsOneWidget);
    });

    testWidgets('completed challenge without badge does not show 배지 획득',
        (tester) async {
      final challenge = ChallengeSummary(
        id: 'test-id',
        title: '물 마시기',
        category: '건강',
        startDate: '2026-03-01',
        endDate: '2026-03-31',
        status: 'completed',
        memberCount: 3,
        achievementRate: 90.0,
        badge: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChallengeCard(challenge: challenge, onTap: () {}),
          ),
        ),
      );

      expect(find.text('배지 획득'), findsNothing);
    });

    testWidgets('achievement rate displays with one decimal place',
        (tester) async {
      final challenge = ChallengeSummary(
        id: 'test-id',
        title: '독서',
        category: '교양',
        startDate: '2026-04-01',
        endDate: '2026-04-30',
        status: 'active',
        memberCount: 2,
        achievementRate: 86.7,
        badge: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChallengeCard(challenge: challenge, onTap: () {}),
          ),
        ),
      );

      expect(find.text('달성률 86.7%'), findsOneWidget);
    });
  });
}
