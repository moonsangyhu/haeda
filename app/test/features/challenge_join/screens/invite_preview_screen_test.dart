import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:haeda/features/challenge_join/providers/invite_preview_provider.dart';
import 'package:haeda/features/challenge_join/providers/join_challenge_provider.dart';
import 'package:haeda/features/challenge_join/screens/invite_preview_screen.dart';
import 'package:haeda/features/challenge_space/models/challenge_detail.dart';

/// 테스트용 ChallengeDetail 픽스처.
final _testChallenge = ChallengeDetail(
  id: 'challenge-uuid-001',
  title: '30일 달리기',
  description: '매일 5km씩 달리기',
  category: '운동',
  startDate: '2026-04-05',
  endDate: '2026-05-04',
  verificationFrequency: {'type': 'daily'},
  photoRequired: false,
  inviteCode: 'ABCD1234',
  status: 'active',
  creator: const MemberBrief(
    id: 'creator-uuid',
    nickname: '김철수',
    profileImageUrl: null,
  ),
  memberCount: 3,
  isMember: false,
  createdAt: '2026-04-04T12:00:00Z',
);

void main() {
  Widget buildTestApp({
    required AsyncValue<ChallengeDetail> previewState,
  }) {
    final router = GoRouter(
      initialLocation: '/invite/ABCD1234',
      routes: [
        GoRoute(
          path: '/invite/:code',
          builder: (context, state) {
            final code = state.pathParameters['code']!;
            return InvitePreviewScreen(inviteCode: code);
          },
        ),
        GoRoute(
          path: '/challenges/:id',
          builder: (context, state) =>
              const Scaffold(body: Text('ChallengeSpace')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        invitePreviewProvider('ABCD1234').overrideWith(
          (ref) async {
            final value = previewState;
            if (value is AsyncData<ChallengeDetail>) return value.value;
            if (value is AsyncError<ChallengeDetail>) {
              throw value.error;
            }
            // loading — never resolves
            await Future<void>.delayed(const Duration(hours: 1));
            throw Exception('timeout');
          },
        ),
        joinChallengeProvider.overrideWith(JoinChallengeNotifier.new),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('챌린지 제목이 표시된다', (tester) async {
    await tester.pumpWidget(
      buildTestApp(previewState: AsyncData(_testChallenge)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('challenge_title')), findsOneWidget);
    expect(find.text('30일 달리기'), findsOneWidget);
  });

  testWidgets('챌린지 설명이 표시된다', (tester) async {
    await tester.pumpWidget(
      buildTestApp(previewState: AsyncData(_testChallenge)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('challenge_description')), findsOneWidget);
    expect(find.text('매일 5km씩 달리기'), findsOneWidget);
  });

  testWidgets('카테고리가 표시된다', (tester) async {
    await tester.pumpWidget(
      buildTestApp(previewState: AsyncData(_testChallenge)),
    );
    await tester.pumpAndSettle();

    expect(find.text('운동'), findsOneWidget);
  });

  testWidgets('기간이 표시된다', (tester) async {
    await tester.pumpWidget(
      buildTestApp(previewState: AsyncData(_testChallenge)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('2026-04-05'), findsWidgets);
    expect(find.textContaining('2026-05-04'), findsWidgets);
  });

  testWidgets('[참여하기] 버튼이 존재한다', (tester) async {
    await tester.pumpWidget(
      buildTestApp(previewState: AsyncData(_testChallenge)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('join_button')), findsOneWidget);
  });

  testWidgets('로딩 중일 때 LoadingWidget이 표시된다', (tester) async {
    // Completer를 사용해 pending timer 없이 로딩 상태를 유지한다.
    final router = GoRouter(
      initialLocation: '/invite/ABCD1234',
      routes: [
        GoRoute(
          path: '/invite/:code',
          builder: (context, state) {
            final code = state.pathParameters['code']!;
            return InvitePreviewScreen(inviteCode: code);
          },
        ),
        GoRoute(
          path: '/challenges/:id',
          builder: (context, state) =>
              const Scaffold(body: Text('ChallengeSpace')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          invitePreviewProvider('ABCD1234').overrideWith(
            (ref) => Future.value(_testChallenge), // 즉시 resolve
          ),
          joinChallengeProvider.overrideWith(JoinChallengeNotifier.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    // pump() 한 번만 — 아직 Future 결과 반영 전, loading 상태
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
