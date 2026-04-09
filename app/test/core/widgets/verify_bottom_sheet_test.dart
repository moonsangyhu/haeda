import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:haeda/core/widgets/verify_bottom_sheet.dart';
import 'package:haeda/features/my_page/models/challenge_summary.dart';
import 'package:haeda/features/my_page/providers/my_challenges_provider.dart';

Widget buildTestApp({required List<ChallengeSummary> challenges}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const VerifyBottomSheet(),
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/challenges/:id/verify',
        builder: (_, __) => const Scaffold(body: Text('verify')),
      ),
      GoRoute(
        path: '/challenges/:id',
        builder: (_, __) => const Scaffold(body: Text('space')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      myChallengesProvider.overrideWith((_) async => challenges),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('활성 챌린지가 없으면 안내 메시지가 표시된다', (tester) async {
    await tester.pumpWidget(buildTestApp(challenges: []));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text('오늘의 인증'), findsOneWidget);
    expect(find.text('참여 중인 챌린지가 없습니다'), findsOneWidget);
  });

  testWidgets('미인증 챌린지가 있으면 ⚡ 미인증 칩이 표시된다', (tester) async {
    final challenges = [
      ChallengeSummary(
        id: 'c1',
        title: '아침 운동',
        category: '운동',
        startDate: '2026-04-01',
        endDate: '2026-04-30',
        status: 'active',
        memberCount: 2,
        achievementRate: 0.5,
        todayVerified: false,
      ),
    ];

    await tester.pumpWidget(buildTestApp(challenges: challenges));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text('아침 운동'), findsOneWidget);
    expect(find.text('⚡ 미인증'), findsOneWidget);
  });

  testWidgets('인증 완료된 챌린지는 ✅ 완료 칩이 표시된다', (tester) async {
    final challenges = [
      ChallengeSummary(
        id: 'c2',
        title: '독서',
        category: '공부',
        startDate: '2026-04-01',
        endDate: '2026-04-30',
        status: 'active',
        memberCount: 1,
        achievementRate: 1.0,
        todayVerified: true,
      ),
    ];

    await tester.pumpWidget(buildTestApp(challenges: challenges));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text('독서'), findsOneWidget);
    expect(find.text('✅ 완료'), findsOneWidget);
    expect(find.text('오늘 모든 챌린지 인증 완료! 대단해요!'), findsOneWidget);
  });

  testWidgets('완료된 챌린지(status=completed)는 표시되지 않는다', (tester) async {
    final challenges = [
      ChallengeSummary(
        id: 'c3',
        title: '지난 챌린지',
        category: '기타',
        startDate: '2026-01-01',
        endDate: '2026-03-31',
        status: 'completed',
        memberCount: 1,
        achievementRate: 0.8,
      ),
    ];

    await tester.pumpWidget(buildTestApp(challenges: challenges));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text('참여 중인 챌린지가 없습니다'), findsOneWidget);
  });
}
