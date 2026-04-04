import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'features/my_page/screens/my_page_screen.dart';
import 'features/challenge_space/screens/challenge_space_screen.dart';
import 'features/challenge_space/screens/create_verification_screen.dart';
import 'features/challenge_space/screens/daily_verifications_screen.dart';
import 'features/challenge_space/screens/verification_detail_screen.dart';
import 'features/challenge_create/screens/challenge_create_step1_screen.dart';
import 'features/challenge_create/screens/challenge_create_step2_screen.dart';
import 'features/challenge_create/screens/challenge_create_complete_screen.dart';
import 'features/challenge_join/screens/invite_preview_screen.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MyPageScreen(),
    ),
    GoRoute(
      path: '/challenges/:id',
      builder: (context, state) {
        final challengeId = state.pathParameters['id']!;
        return ChallengeSpaceScreen(challengeId: challengeId);
      },
    ),
    GoRoute(
      path: '/challenges/:id/verify',
      builder: (context, state) {
        final challengeId = state.pathParameters['id']!;
        return CreateVerificationScreen(challengeId: challengeId);
      },
    ),
    GoRoute(
      path: '/challenges/:id/verifications/:date',
      builder: (context, state) {
        final challengeId = state.pathParameters['id']!;
        final date = state.pathParameters['date']!;
        return DailyVerificationsScreen(
          challengeId: challengeId,
          date: date,
        );
      },
    ),
    GoRoute(
      path: '/verifications/:id',
      builder: (context, state) {
        final verificationId = state.pathParameters['id']!;
        return VerificationDetailScreen(verificationId: verificationId);
      },
    ),
    // Flow 3: 챌린지 생성
    GoRoute(
      path: '/create',
      builder: (context, state) => const ChallengeCreateStep1Screen(),
    ),
    GoRoute(
      path: '/create/step2',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return ChallengeCreateStep2Screen(step1Data: extra);
      },
    ),
    GoRoute(
      path: '/create/complete/:id',
      builder: (context, state) {
        final challengeId = state.pathParameters['id']!;
        final inviteCode = state.extra as String? ?? '';
        return ChallengeCreateCompleteScreen(
          challengeId: challengeId,
          inviteCode: inviteCode,
        );
      },
    ),
    // Flow 4-A: 초대 링크를 통한 참여
    GoRoute(
      path: '/invite/:code',
      builder: (context, state) {
        final code = state.pathParameters['code']!;
        return InvitePreviewScreen(inviteCode: code);
      },
    ),
  ],
);

class HaedaApp extends StatelessWidget {
  const HaedaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '해다',
      routerConfig: _router,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF50)),
        useMaterial3: true,
      ),
    );
  }
}
