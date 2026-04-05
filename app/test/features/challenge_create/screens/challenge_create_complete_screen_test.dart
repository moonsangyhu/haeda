import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:haeda/features/challenge_create/screens/challenge_create_complete_screen.dart';

void main() {
  const testChallengeId = 'test-challenge-id-123';
  const testInviteCode = 'ABCD1234';

  Widget buildTestApp() {
    final router = GoRouter(
      initialLocation: '/create/complete/$testChallengeId',
      routes: [
        GoRoute(
          path: '/create/complete/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final code = state.extra as String? ?? testInviteCode;
            return ChallengeCreateCompleteScreen(
              challengeId: id,
              inviteCode: code,
            );
          },
        ),
        GoRoute(
          path: '/my-page',
          builder: (context, state) =>
              const Scaffold(body: Text('MyPage')),
        ),
      ],
      // extra는 router.go로만 전달 가능하므로 직접 생성
    );

    return ProviderScope(
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Widget buildDirect() {
    return ProviderScope(
      child: MaterialApp(
        home: ChallengeCreateCompleteScreen(
          challengeId: testChallengeId,
          inviteCode: testInviteCode,
        ),
      ),
    );
  }

  testWidgets('초대 코드가 표시된다', (tester) async {
    await tester.pumpWidget(buildDirect());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('invite_code_text')), findsOneWidget);
    expect(find.text(testInviteCode), findsOneWidget);
  });

  testWidgets('[코드 복사] 버튼이 존재한다', (tester) async {
    await tester.pumpWidget(buildDirect());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('copy_code_button')), findsOneWidget);
  });

  testWidgets('[카카오톡으로 공유] 버튼이 존재한다', (tester) async {
    await tester.pumpWidget(buildDirect());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kakao_share_button')), findsOneWidget);
  });

  testWidgets('[확인] 버튼이 존재한다', (tester) async {
    await tester.pumpWidget(buildDirect());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('confirm_button')), findsOneWidget);
  });

  testWidgets('"생성 완료!" 텍스트가 표시된다', (tester) async {
    await tester.pumpWidget(buildDirect());
    await tester.pumpAndSettle();

    expect(find.text('생성 완료!'), findsOneWidget);
  });

  testWidgets('[확인] 버튼 탭 시 내 페이지로 이동한다', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => ChallengeCreateCompleteScreen(
            challengeId: testChallengeId,
            inviteCode: testInviteCode,
          ),
        ),
        GoRoute(
          path: '/my-page',
          builder: (context, state) =>
              const Scaffold(body: Text('MyPage')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirm_button')));
    await tester.pumpAndSettle();

    expect(find.text('MyPage'), findsOneWidget);
  });
}
