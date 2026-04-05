import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:haeda/features/auth/models/auth_models.dart';
import 'package:haeda/features/auth/providers/auth_provider.dart';
import 'package:haeda/features/auth/screens/login_screen.dart';

Widget _buildTestApp({List<Override> overrides = const []}) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/kakao-oauth',
        builder: (context, state) => const Scaffold(body: Text('카카오 OAuth')),
      ),
      GoRoute(
        path: '/my-page',
        builder: (context, state) => const Scaffold(body: Text('내 페이지')),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const Scaffold(body: Text('프로필 설정')),
      ),
    ],
  );

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: router),
  );
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

    testWidgets('KAKAO_APP_KEY 미설정 시 테스트 계정 버튼이 표시된다', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();
      expect(find.text('김철수'), findsOneWidget);
      expect(find.text('이영희'), findsOneWidget);
      expect(find.text('박지민'), findsOneWidget);
    });

    testWidgets(
        'KAKAO_APP_KEY 미설정 시 테스트 계정 탭하면 /my-page로 이동한다',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(overrides: [
          authStateProvider.overrideWith(
            () => _MockAuthNotifier(isNew: false),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('김철수'));
      await tester.pumpAndSettle();

      expect(find.text('내 페이지'), findsOneWidget);
    });

    testWidgets(
        'KAKAO_APP_KEY 미설정 시 isNew=true 이면 /profile-setup으로 이동한다',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(overrides: [
          authStateProvider.overrideWith(
            () => _MockAuthNotifier(isNew: true),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('이영희'));
      await tester.pumpAndSettle();

      expect(find.text('프로필 설정'), findsOneWidget);
    });
  });
}

class _MockAuthNotifier extends AuthState {
  _MockAuthNotifier({required this.isNew});
  final bool isNew;

  @override
  AsyncValue<AuthUser?> build() => const AsyncData(null);

  @override
  Future<AuthUser> devLogin({int userIndex = 1}) async {
    return AuthUser(id: 'test-user', isNew: isNew);
  }
}
