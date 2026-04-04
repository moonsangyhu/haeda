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
          path: '/challenges/:id',
          builder: (context, state) =>
              const Scaffold(body: Text('ChallengeSpace')),
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

  testWidgets('[링크 복사] 버튼이 존재한다', (tester) async {
    await tester.pumpWidget(buildDirect());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('copy_button')), findsOneWidget);
  });

  testWidgets('[챌린지로 이동] 버튼이 존재한다', (tester) async {
    await tester.pumpWidget(buildDirect());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('go_to_challenge_button')), findsOneWidget);
  });

  testWidgets('"생성 완료!" 텍스트가 표시된다', (tester) async {
    await tester.pumpWidget(buildDirect());
    await tester.pumpAndSettle();

    expect(find.text('생성 완료!'), findsOneWidget);
  });

  testWidgets('[챌린지로 이동] 버튼 탭 시 챌린지 공간으로 이동한다', (tester) async {
    final navigatedTo = <String>[];
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
          path: '/challenges/:id',
          builder: (context, state) {
            navigatedTo.add(state.pathParameters['id']!);
            return const Scaffold(body: Text('ChallengeSpace'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('go_to_challenge_button')));
    await tester.pumpAndSettle();

    expect(find.text('ChallengeSpace'), findsOneWidget);
    expect(navigatedTo, contains(testChallengeId));
  });
}
