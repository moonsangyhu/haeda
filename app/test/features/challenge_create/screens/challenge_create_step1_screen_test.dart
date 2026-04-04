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

  testWidgets('[다음] 버튼이 존재한다', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('next_button')), findsOneWidget);
  });

  testWidgets('필수 필드 미입력 시 유효성 검사 오류가 표시된다', (tester) async {
    await tester.pumpWidget(buildTestApp());
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

    await tester.tap(find.byKey(const Key('next_button')));
    await tester.pumpAndSettle();

    expect(find.text('Step2'), findsOneWidget);
  });
}
