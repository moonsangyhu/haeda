import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:haeda/features/my_page/models/challenge_summary.dart';
import 'package:haeda/features/my_page/providers/my_challenges_provider.dart';
import 'package:haeda/features/status_bar/models/user_stats.dart';
import 'package:haeda/features/status_bar/providers/user_stats_provider.dart';
import 'package:haeda/features/status_bar/widgets/status_bar.dart';

ChallengeSummary _challengeSummary({
  required String id,
  required String icon,
  required String title,
}) =>
    ChallengeSummary(
      id: id,
      title: title,
      category: 'cat',
      startDate: '2026-04-01',
      endDate: '2026-05-01',
      status: 'active',
      memberCount: 1,
      achievementRate: 0.0,
      icon: icon,
    );

void main() {
  group('StatusBar', () {
    testWidgets('shows fixed-height SizedBox while loading', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userStatsProvider.overrideWith((ref) async {
              await Future<void>.delayed(const Duration(days: 365));
              return const UserStats(
                streak: 0,
                verifiedToday: false,
                activeChallenges: 0,
                completedChallenges: 0,
                gems: 0,
              );
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(body: StatusBar()),
          ),
        ),
      );
      // Before the future resolves, should show SizedBox(height: 44)
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('hides when error occurs', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userStatsProvider.overrideWith((ref) async {
              throw Exception('network error');
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(body: StatusBar()),
          ),
        ),
      );
      await tester.pump();
      // Error state renders SizedBox.shrink — no stat text visible
      expect(find.textContaining('/'), findsNothing);
    });

    testWidgets('shows verified flower icon when verifiedToday is true',
        (tester) async {
      const stats = UserStats(
        streak: 7,
        verifiedToday: true,
        activeChallenges: 3,
        completedChallenges: 2,
        gems: 120,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userStatsProvider.overrideWith((_) async => stats),
          ],
          child: const MaterialApp(
            home: Scaffold(body: StatusBar()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('🌺'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('shows wilted flower icon when verifiedToday is false',
        (tester) async {
      const stats = UserStats(
        streak: 3,
        verifiedToday: false,
        activeChallenges: 2,
        completedChallenges: 1,
        gems: 50,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userStatsProvider.overrideWith((_) async => stats),
          ],
          child: const MaterialApp(
            home: Scaffold(body: StatusBar()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('🥀'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('challenge pill shows fallback lightning when no challenges',
        (tester) async {
      const stats = UserStats(
        streak: 5,
        verifiedToday: true,
        activeChallenges: 0,
        completedChallenges: 0,
        gems: 200,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userStatsProvider.overrideWith((_) async => stats),
            myChallengesProvider
                .overrideWith((_) async => const <ChallengeSummary>[]),
          ],
          child: const MaterialApp(
            home: Scaffold(body: StatusBar()),
          ),
        ),
      );
      await tester.pump();

      // active count = 0 (no most-recent + no count)
      expect(find.descendant(
        of: find.byKey(const Key('challenge_pill')),
        matching: find.text('0'),
      ), findsOneWidget);
      // fallback lightning SVG 존재
      expect(find.descendant(
        of: find.byKey(const Key('challenge_pill')),
        matching: find.byType(SvgPicture),
      ), findsOneWidget);
    });

    testWidgets('challenge pill shows most-recent emoji + active count',
        (tester) async {
      const stats = UserStats(
        streak: 5,
        verifiedToday: true,
        activeChallenges: 3,
        completedChallenges: 2,
        gems: 200,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userStatsProvider.overrideWith((_) async => stats),
            myChallengesProvider.overrideWith((_) async => [
                  _challengeSummary(id: 'abc', icon: '🏃', title: '아침 운동'),
                ]),
          ],
          child: const MaterialApp(
            home: Scaffold(body: StatusBar()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 가장 최근 챌린지의 이모지가 보임
      expect(find.text('🏃'), findsOneWidget);
      // active count = 3
      expect(find.descendant(
        of: find.byKey(const Key('challenge_pill')),
        matching: find.text('3'),
      ), findsOneWidget);
    });

    testWidgets('tapping challenge pill (with most-recent) pushes /challenges/:id',
        (tester) async {
      const stats = UserStats(
        streak: 5,
        verifiedToday: true,
        activeChallenges: 3,
        completedChallenges: 0,
        gems: 100,
      );

      String? pushedRoute;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: StatusBar()),
          ),
          GoRoute(
            path: '/challenges/:id',
            builder: (context, state) {
              pushedRoute = '/challenges/${state.pathParameters['id']}';
              return const Scaffold(body: Text('challenge space'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userStatsProvider.overrideWith((_) async => stats),
            myChallengesProvider.overrideWith((_) async => [
                  _challengeSummary(id: 'abc-123', icon: '🏃', title: '아침 운동'),
                ]),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('challenge_pill')));
      await tester.pumpAndSettle();

      expect(pushedRoute, '/challenges/abc-123');
    });

    testWidgets('tapping challenge pill (no challenges) pushes /create',
        (tester) async {
      const stats = UserStats(
        streak: 0,
        verifiedToday: false,
        activeChallenges: 0,
        completedChallenges: 0,
        gems: 0,
      );

      String? pushedRoute;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: StatusBar()),
          ),
          GoRoute(
            path: '/create',
            builder: (context, state) {
              pushedRoute = '/create';
              return const Scaffold(body: Text('create'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userStatsProvider.overrideWith((_) async => stats),
            myChallengesProvider
                .overrideWith((_) async => const <ChallengeSummary>[]),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('challenge_pill')));
      await tester.pumpAndSettle();

      expect(pushedRoute, '/create');
    });

    testWidgets('displays gems value with diamond icon', (tester) async {
      const stats = UserStats(
        streak: 1,
        verifiedToday: false,
        activeChallenges: 1,
        completedChallenges: 0,
        gems: 999,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userStatsProvider.overrideWith((_) async => stats),
          ],
          child: const MaterialApp(
            home: Scaffold(body: StatusBar()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('💎'), findsOneWidget);
      expect(find.text('999'), findsOneWidget);
    });

    testWidgets('tapping streak pill pushes /streak route', (tester) async {
      const stats = UserStats(
        streak: 7,
        verifiedToday: true,
        activeChallenges: 3,
        completedChallenges: 2,
        gems: 120,
      );

      String? pushedRoute;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: StatusBar()),
          ),
          GoRoute(
            path: '/streak',
            builder: (context, state) {
              pushedRoute = '/streak';
              return const Scaffold(body: Text('streak page'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [userStatsProvider.overrideWith((_) async => stats)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('7'));
      await tester.pumpAndSettle();

      expect(pushedRoute, '/streak');
    });

    testWidgets('tapping gem pill pushes /gems route', (tester) async {
      const stats = UserStats(
        streak: 7,
        verifiedToday: true,
        activeChallenges: 3,
        completedChallenges: 2,
        gems: 120,
      );

      String? pushedRoute;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: StatusBar()),
          ),
          GoRoute(
            path: '/gems',
            builder: (context, state) {
              pushedRoute = '/gems';
              return const Scaffold(body: Text('gems page'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [userStatsProvider.overrideWith((_) async => stats)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('120'));
      await tester.pumpAndSettle();

      expect(pushedRoute, '/gems');
    });
  });
}
