import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';
import 'core/widgets/main_shell.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/kakao_oauth_screen.dart';
import 'features/auth/screens/profile_setup_screen.dart';
import 'features/my_page/screens/my_page_screen.dart';
import 'features/feed/screens/feed_screen.dart';
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
import 'features/character/screens/my_room_screen.dart';
import 'features/character/screens/shop_screen.dart';
import 'features/character/screens/character_creation_screen.dart';
import 'features/friends/screens/friend_list_screen.dart';
import 'features/friends/screens/friend_requests_screen.dart';
import 'features/friends/screens/contact_search_screen.dart';

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
    // Bottom tab shell: 내 방 / 상점 / 챌린지(center) / 피드 / 설정
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        // index 0: 내 방
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/my-room',
              builder: (context, state) => const MyRoomScreen(),
            ),
          ],
        ),
        // index 1: 상점
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/shop',
              builder: (context, state) => const ShopScreen(),
            ),
          ],
        ),
        // index 2: 챌린지 (center, elevated)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/my-page',
              builder: (context, state) => const MyPageScreen(),
            ),
          ],
        ),
        // index 3: 피드
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/feed',
              builder: (context, state) => const FeedScreen(),
            ),
          ],
        ),
        // index 4: 설정
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
    // 캐릭터 외형 생성
    GoRoute(
      path: '/character-create',
      builder: (context, state) => const CharacterCreationScreen(),
    ),
    // 친구 관리
    GoRoute(
      path: '/friends',
      builder: (context, state) => const FriendListScreen(),
    ),
    GoRoute(
      path: '/friends/requests',
      builder: (context, state) => const FriendRequestsScreen(),
    ),
    GoRoute(
      path: '/friends/contact-search',
      builder: (context, state) => const ContactSearchScreen(),
    ),
  ],
);

class HaedaApp extends ConsumerWidget {
  const HaedaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      title: '해다',
      routerConfig: _router,
      theme: AppTheme.theme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
    );
  }
}
