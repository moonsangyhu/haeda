import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:haeda/features/my_page/models/challenge_summary.dart';
import 'package:haeda/features/my_page/providers/my_challenges_provider.dart';
import 'package:haeda/features/my_page/screens/my_page_screen.dart';

ChallengeSummary _active({
  String id = 'active-1',
  String title = '운동 30일',
  double achievementRate = 73.3,
}) =>
    ChallengeSummary(
      id: id,
      title: title,
      category: '운동',
      startDate: '2026-04-01',
      endDate: '2026-04-30',
      status: 'active',
      memberCount: 5,
      achievementRate: achievementRate,
      badge: null,
    );

ChallengeSummary _completed({
  String id = 'completed-1',
  String title = '물 마시기',
  double achievementRate = 90.0,
  String? badge = 'completed',
}) =>
    ChallengeSummary(
      id: id,
      title: title,
      category: '건강',
      startDate: '2026-03-01',
      endDate: '2026-03-31',
      status: 'completed',
      memberCount: 3,
      achievementRate: achievementRate,
      badge: badge,
    );

Widget _buildTestApp({required Override providerOverride}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const MyPageScreen(),
      ),
      GoRoute(
        path: '/create',
        builder: (context, state) =>
            const Scaffold(body: Text('챌린지 만들기 화면')),
      ),
      GoRoute(
        path: '/challenges/:id',
        builder: (context, state) =>
            Scaffold(body: Text('챌린지 공간 ${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/challenges/:id/completion',
        builder: (context, state) =>
            Scaffold(body: Text('완료 결과 ${state.pathParameters['id']}')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [providerOverride],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('MyPageScreen', () {
    testWidgets('active 챌린지와 completed 챌린지가 분리되어 표시된다',
        (tester) async {
      final challenges = [_active(), _completed()];
      await tester.pumpWidget(_buildTestApp(
        providerOverride:
            myChallengesProvider.overrideWith((_) async => challenges),
      ));
      await tester.pumpAndSettle();

      expect(find.text('참여 중인 챌린지'), findsOneWidget);
      expect(find.text('완료된 챌린지'), findsOneWidget);
      expect(find.text('운동 30일'), findsOneWidget);
      expect(find.text('물 마시기 (완료)'), findsOneWidget);
    });

    testWidgets('챌린지가 없으면 빈 상태 메시지가 표시된다', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        providerOverride:
            myChallengesProvider.overrideWith((_) async => <ChallengeSummary>[]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('참여 중인 챌린지가 없습니다.'), findsOneWidget);
      expect(find.text('참여 중인 챌린지'), findsNothing);
      expect(find.text('완료된 챌린지'), findsNothing);
    });

    testWidgets('loading 상태에서 로딩 위젯이 표시된다', (tester) async {
      final completer = Completer<List<ChallengeSummary>>();
      await tester.pumpWidget(_buildTestApp(
        providerOverride:
            myChallengesProvider.overrideWith((_) => completer.future),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets('error 상태에서 에러 메시지와 재시도 버튼이 표시된다',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(
        providerOverride: myChallengesProvider
            .overrideWith((_) async => throw Exception('서버 오류')),
      ));
      await tester.pumpAndSettle();

      expect(find.text('다시 시도'), findsOneWidget);
    });

    testWidgets('completed 챌린지에 badge가 있으면 배지 획득이 표시된다',
        (tester) async {
      final challenges = [_completed(badge: 'completed')];
      await tester.pumpWidget(_buildTestApp(
        providerOverride:
            myChallengesProvider.overrideWith((_) async => challenges),
      ));
      await tester.pumpAndSettle();

      expect(find.text('배지 획득'), findsOneWidget);
    });

    testWidgets('completed 챌린지에 badge가 없으면 배지 획득이 없다',
        (tester) async {
      final challenges = [_completed(badge: null)];
      await tester.pumpWidget(_buildTestApp(
        providerOverride:
            myChallengesProvider.overrideWith((_) async => challenges),
      ));
      await tester.pumpAndSettle();

      expect(find.text('배지 획득'), findsNothing);
    });

    testWidgets('active만 있을 때 완료 섹션이 없다', (tester) async {
      final challenges = [_active()];
      await tester.pumpWidget(_buildTestApp(
        providerOverride:
            myChallengesProvider.overrideWith((_) async => challenges),
      ));
      await tester.pumpAndSettle();

      expect(find.text('참여 중인 챌린지'), findsOneWidget);
      expect(find.text('완료된 챌린지'), findsNothing);
    });

    testWidgets('completed만 있을 때 참여 중 섹션이 없다', (tester) async {
      final challenges = [_completed()];
      await tester.pumpWidget(_buildTestApp(
        providerOverride:
            myChallengesProvider.overrideWith((_) async => challenges),
      ));
      await tester.pumpAndSettle();

      expect(find.text('참여 중인 챌린지'), findsNothing);
      expect(find.text('완료된 챌린지'), findsOneWidget);
    });

    testWidgets('챌린지 만들기 버튼이 표시된다', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        providerOverride:
            myChallengesProvider.overrideWith((_) async => <ChallengeSummary>[]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('챌린지 만들기'), findsOneWidget);
    });
  });
}
