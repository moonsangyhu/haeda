import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:haeda/features/challenge_create/screens/challenge_create_step1_screen.dart';

void main() {
  Widget buildTestApp() {
    final router = GoRouter(
      initialLocation: '/create',
      routes: [
        GoRoute(
          path: '/create',
          builder: (context, state) =>
              const ChallengeCreateStep1Screen(),
        ),
        GoRoute(
          path: '/create/step2',
          builder: (context, state) =>
              const Scaffold(body: Text('Step2')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Text('Home')),
        ),
      ],
    );

    return ProviderScope(
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('카테고리 TextField가 존재한다', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('category_field')), findsOneWidget);
  });

  testWidgets('제목 TextField가 존재한다', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('title_field')), findsOneWidget);
  });

  testWidgets('설명 TextField가 존재한다', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('description_field')), findsOneWidget);
  });

  testWidgets('이모지 preset wrap 이 노출된다', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('emoji_preset_wrap')), findsOneWidget);
    expect(find.byKey(const Key('emoji_custom_toggle')), findsOneWidget);
  });

  testWidgets('[다음] 버튼이 존재한다', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('next_button')), findsOneWidget);
  });

  testWidgets('필수 필드 미입력 시 유효성 검사 오류가 표시된다', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();

    expect(find.text('카테고리를 입력해주세요.'), findsOneWidget);
    expect(find.text('제목을 입력해주세요.'), findsOneWidget);
  });

  testWidgets('필수 필드 입력 후 [다음] 버튼 탭 시 Step2로 이동한다', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('category_field')), '운동');
    await tester.enterText(
        find.byKey(const Key('title_field')), '30일 달리기');

    await tester.ensureVisible(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();

    expect(find.text('Step2'), findsOneWidget);
  });

  testWidgets('카테고리 "운동" 입력 시 preset 이 sport preset 으로 갱신된다', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // 초기 universal preset 에는 🏋️ 가 없고, sport preset 에는 있다.
    expect(find.byKey(const Key('emoji_preset_🏋️')), findsNothing);

    await tester.enterText(
        find.byKey(const Key('category_field')), '운동');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('emoji_preset_🏋️')), findsOneWidget);
    expect(find.byKey(const Key('emoji_preset_💪')), findsOneWidget);
  });

  group('emoji forwarding', () {
    testWidgets('blank emoji uses default 🎯', (tester) async {
      Map<String, dynamic>? capturedExtra;
      final router = GoRouter(
        initialLocation: '/create',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('home')),
          ),
          GoRoute(
            path: '/create',
            builder: (_, __) => const ChallengeCreateStep1Screen(),
          ),
          GoRoute(
            path: '/create/step2',
            builder: (context, state) {
              capturedExtra = state.extra as Map<String, dynamic>?;
              return const Scaffold(body: Text('step2'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('category_field')), '운동');
      await tester.enterText(find.byKey(const Key('title_field')), '아침 운동');
      await tester.ensureVisible(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('next_button')));
      await tester.pumpAndSettle();

      expect(capturedExtra, isNotNull);
      expect(capturedExtra!['icon'], '🎯');
    });

    testWidgets('preset chip 탭 시 해당 이모지가 forward 된다', (tester) async {
      Map<String, dynamic>? capturedExtra;
      final router = GoRouter(
        initialLocation: '/create',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('home')),
          ),
          GoRoute(
            path: '/create',
            builder: (_, __) => const ChallengeCreateStep1Screen(),
          ),
          GoRoute(
            path: '/create/step2',
            builder: (context, state) {
              capturedExtra = state.extra as Map<String, dynamic>?;
              return const Scaffold(body: Text('step2'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('emoji_preset_💪')));
      await tester.tap(find.byKey(const Key('emoji_preset_💪')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('category_field')), '운동');
      await tester.enterText(find.byKey(const Key('title_field')), '러닝');
      await tester.ensureVisible(find.byKey(const Key('next_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('next_button')));
      await tester.pumpAndSettle();

      expect(capturedExtra!['icon'], '💪');
    });

    testWidgets('직접 입력 토글 후 입력값이 forward 된다', (tester) async {
      Map<String, dynamic>? capturedExtra;
      final router = GoRouter(
        initialLocation: '/create',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('home')),
          ),
          GoRoute(
            path: '/create',
            builder: (_, __) => const ChallengeCreateStep1Screen(),
          ),
          GoRoute(
            path: '/create/step2',
            builder: (context, state) {
              capturedExtra = state.extra as Map<String, dynamic>?;
              return const Scaffold(body: Text('step2'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('emoji_custom_toggle')));
      await tester.tap(find.byKey(const Key('emoji_custom_toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('emoji_custom_field')), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('emoji_custom_field')), '🦄');
      await tester.enterText(find.byKey(const Key('category_field')), '습관');
      await tester.enterText(find.byKey(const Key('title_field')), '유니콘');
      await tester.ensureVisible(find.byKey(const Key('next_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('next_button')));
      await tester.pumpAndSettle();

      expect(capturedExtra!['icon'], '🦄');
    });
  });
}
