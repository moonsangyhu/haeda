import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'core/widgets/main_shell.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/kakao_oauth_screen.dart';
import 'features/auth/screens/profile_setup_screen.dart';
import 'features/my_page/screens/my_page_screen.dart';
import 'features/explore/screens/explore_screen.dart';
import 'features/notifications/screens/notifications_placeholder_screen.dart';
import 'features/challenge_space/screens/challenge_space_screen.dart';
import 'features/challenge_space/screens/create_verification_screen.dart';
import 'features/challenge_space/screens/daily_verifications_screen.dart';
import 'features/challenge_space/screens/verification_detail_screen.dart';
import 'features/challenge_create/screens/challenge_create_step1_screen.dart';
import 'features/challenge_create/screens/challenge_create_step2_screen.dart';
import 'features/challenge_create/screens/challenge_create_complete_screen.dart';
import 'features/challenge_join/screens/invite_preview_screen.dart';
import 'features/challenge_complete/screens/challenge_completion_screen.dart';
import 'features/settings/screens/settings_screen.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    // Auth flow
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/kakao-oauth',
      builder: (context, state) => const KakaoOAuthScreen(),
    ),
    GoRoute(
      path: '/profile-setup',
      builder: (context, state) => const ProfileSetupScreen(),
    ),
    // Bottom tab shell: 내 챌린지 / 탐색 / 알림 / 설정
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/my-page',
              builder: (context, state) => const MyPageScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/explore',
              builder: (context, state) => const ExploreScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/notifications',
              builder: (context, state) =>
                  const NotificationsPlaceholderScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
    // Detail screens (navigate away from shell)
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
        final date = state.uri.queryParameters['date'];
        return CreateVerificationScreen(
          challengeId: challengeId,
          date: date,
        );
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
    // Flow 8: 챌린지 완료 결과
    GoRoute(
      path: '/challenges/:id/completion',
      builder: (context, state) {
        final challengeId = state.pathParameters['id']!;
        return ChallengeCompletionScreen(challengeId: challengeId);
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
      theme: AppTheme.theme,
    );
  }
}
