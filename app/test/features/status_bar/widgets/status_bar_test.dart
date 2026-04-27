import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:haeda/features/status_bar/models/user_stats.dart';
import 'package:haeda/features/status_bar/providers/user_stats_provider.dart';
import 'package:haeda/features/status_bar/widgets/status_bar.dart';

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

    testWidgets('displays challenges as active/completed ratio', (tester) async {
      const stats = UserStats(
        streak: 5,
        verifiedToday: true,
        activeChallenges: 4,
        completedChallenges: 6,
        gems: 200,
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

      expect(find.text('4/6'), findsOneWidget);
      expect(find.text('🏃'), findsOneWidget);
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
  });
}
