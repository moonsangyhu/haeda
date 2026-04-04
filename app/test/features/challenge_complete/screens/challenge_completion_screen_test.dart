import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:haeda/features/challenge_complete/models/completion_result.dart';
import 'package:haeda/features/challenge_complete/providers/completion_provider.dart';
import 'package:haeda/features/challenge_complete/screens/challenge_completion_screen.dart';

// 테스트용 CompletionResult 픽스처
CompletionResult _makeResult({String? badge}) => CompletionResult(
      challengeId: 'test-challenge-id',
      title: '운동 30일',
      category: '운동',
      startDate: '2026-03-05',
      endDate: '2026-04-03',
      totalDays: 30,
      myResult: MyResult(
        userId: 'user-1',
        achievementRate: 86.7,
        verifiedDays: 26,
        expectedDays: 30,
        badge: badge,
      ),
      members: [
        MemberResult(
          userId: 'user-1',
          nickname: '김철수',
          profileImageUrl: null,
          achievementRate: 90.0,
          verifiedDays: 27,
          badge: badge,
        ),
        MemberResult(
          userId: 'user-2',
          nickname: '이영희',
          profileImageUrl: null,
          achievementRate: 80.0,
          verifiedDays: 24,
          badge: null,
        ),
      ],
      dayCompletions: 12,
      calendarSummary: CalendarSummary(
        totalDays: 30,
        allCompletedDays: 12,
        seasonIconTypes: ['spring'],
      ),
    );

Widget _buildTestApp({
  required Override providerOverride,
}) {
  final router = GoRouter(
    initialLocation: '/challenges/test-challenge-id/completion',
    routes: [
      GoRoute(
        path: '/challenges/:id/completion',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ChallengeCompletionScreen(challengeId: id);
        },
      ),
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Text('내 페이지')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [providerOverride],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  const challengeId = 'test-challenge-id';

  group('ChallengeCompletionScreen', () {
    testWidgets('챌린지 제목이 렌더링된다', (tester) async {
      final result = _makeResult();
      await tester.pumpWidget(_buildTestApp(
        providerOverride: completionProvider(challengeId)
            .overrideWith((_) async => result),
      ));
      await tester.pumpAndSettle();

      expect(find.text('운동 30일'), findsOneWidget);
    });

    testWidgets('기간이 표시된다', (tester) async {
      final result = _makeResult();
      await tester.pumpWidget(_buildTestApp(
        providerOverride: completionProvider(challengeId)
            .overrideWith((_) async => result),
      ));
      await tester.pumpAndSettle();

      expect(find.text('2026-03-05 ~ 2026-04-03'), findsOneWidget);
    });

    testWidgets('나의 달성률이 표시된다', (tester) async {
      final result = _makeResult();
      await tester.pumpWidget(_buildTestApp(
        providerOverride: completionProvider(challengeId)
            .overrideWith((_) async => result),
      ));
      await tester.pumpAndSettle();

      expect(find.text('86.7%'), findsOneWidget);
    });

    testWidgets('verified_days / expected_days 가 표시된다', (tester) async {
      final result = _makeResult();
      await tester.pumpWidget(_buildTestApp(
        providerOverride: completionProvider(challengeId)
            .overrideWith((_) async => result),
      ));
      await tester.pumpAndSettle();

      expect(find.text('26 / 30일'), findsOneWidget);
    });

    testWidgets('badge가 있으면 완료 배지 획득 텍스트가 표시된다', (tester) async {
      final result = _makeResult(badge: 'completed');
      await tester.pumpWidget(_buildTestApp(
        providerOverride: completionProvider(challengeId)
            .overrideWith((_) async => result),
      ));
      await tester.pumpAndSettle();

      expect(find.text('🏅 완료 배지 획득!'), findsOneWidget);
    });

    testWidgets('badge가 없으면 완료 배지 텍스트가 표시되지 않는다', (tester) async {
      final result = _makeResult(badge: null);
      await tester.pumpWidget(_buildTestApp(
        providerOverride: completionProvider(challengeId)
            .overrideWith((_) async => result),
      ));
      await tester.pumpAndSettle();

      expect(find.text('🏅 완료 배지 획득!'), findsNothing);
    });

    testWidgets('참여자 목록 - 닉네임이 렌더링된다', (tester) async {
      final result = _makeResult();
      await tester.pumpWidget(_buildTestApp(
        providerOverride: completionProvider(challengeId)
            .overrideWith((_) async => result),
      ));
      await tester.pumpAndSettle();

      expect(find.text('김철수'), findsOneWidget);
      expect(find.text('이영희'), findsOneWidget);
    });

    testWidgets('참여자 목록 - 달성률이 렌더링된다', (tester) async {
      final result = _makeResult();
      await tester.pumpWidget(_buildTestApp(
        providerOverride: completionProvider(challengeId)
            .overrideWith((_) async => result),
      ));
      await tester.pumpAndSettle();

      expect(find.text('90.0%'), findsOneWidget);
      expect(find.text('80.0%'), findsOneWidget);
    });

    testWidgets('전원 인증 일수가 표시된다', (tester) async {
      final result = _makeResult();
      await tester.pumpWidget(_buildTestApp(
        providerOverride: completionProvider(challengeId)
            .overrideWith((_) async => result),
      ));
      await tester.pumpAndSettle();

      expect(find.text('12일'), findsOneWidget);
    });

    testWidgets('"내 페이지로" 버튼이 존재한다', (tester) async {
      final result = _makeResult();
      await tester.pumpWidget(_buildTestApp(
        providerOverride: completionProvider(challengeId)
            .overrideWith((_) async => result),
      ));
      await tester.pumpAndSettle();

      expect(find.text('내 페이지로'), findsOneWidget);
    });

    testWidgets('"내 페이지로" 버튼 탭 시 / 로 이동한다', (tester) async {
      final result = _makeResult();
      await tester.pumpWidget(_buildTestApp(
        providerOverride: completionProvider(challengeId)
            .overrideWith((_) async => result),
      ));
      await tester.pumpAndSettle();

      // 버튼이 스크롤 가능한 영역 아래에 있을 수 있으므로 스크롤 후 탭
      await tester.scrollUntilVisible(
        find.text('내 페이지로'),
        100,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text('내 페이지로'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('내 페이지'), findsOneWidget);
    });

    testWidgets('loading 상태에서 CircularProgressIndicator가 표시된다',
        (tester) async {
      // 완료되지 않는 Future를 사용해 loading 상태를 유지
      final completer = Completer<CompletionResult>();
      await tester.pumpWidget(_buildTestApp(
        providerOverride: completionProvider(challengeId)
            .overrideWith((_) => completer.future),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 테스트 종료 전 completer 완료 처리 (pending timer 방지)
      completer.complete(_makeResult());
      await tester.pumpAndSettle();
    });

    testWidgets('error 상태에서 에러 메시지와 재시도 버튼이 표시된다', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        providerOverride: completionProvider(challengeId)
            .overrideWith((_) async => throw Exception('서버 오류')),
      ));
      await tester.pumpAndSettle();

      expect(find.text('오류가 발생했습니다.'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });
  });
}
