import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:haeda/features/auth/screens/login_screen.dart';

Widget _buildTestApp({String? navigatedTo}) {
  String? captured;
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/kakao-oauth',
        builder: (context, state) {
          captured = '/kakao-oauth';
          return const Scaffold(body: Text('카카오 OAuth'));
        },
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

void main() {
  group('LoginScreen', () {
    testWidgets('앱 이름 "해다"가 표시된다', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();
      expect(find.text('해다'), findsOneWidget);
    });

    testWidgets('서브타이틀 "협력형 챌린지 달력"이 표시된다', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();
      expect(find.text('협력형 챌린지 달력'), findsOneWidget);
    });

    testWidgets('"카카오로 시작하기" 버튼이 표시된다', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();
      expect(find.text('카카오로 시작하기'), findsOneWidget);
    });

    testWidgets('"카카오로 시작하기" 버튼 탭 시 /kakao-oauth로 이동한다',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('카카오로 시작하기'));
      await tester.pumpAndSettle();

      expect(find.text('카카오 OAuth'), findsOneWidget);
    });
  });
}
