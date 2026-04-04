import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'features/my_page/screens/my_page_screen.dart';
import 'features/challenge_space/screens/challenge_space_screen.dart';
import 'features/challenge_space/screens/create_verification_screen.dart';
import 'features/challenge_space/screens/daily_verifications_screen.dart';

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
