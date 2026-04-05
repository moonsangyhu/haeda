import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:haeda/features/auth/providers/auth_provider.dart';
import 'package:haeda/features/auth/screens/profile_setup_screen.dart';
import 'package:haeda/features/auth/models/auth_models.dart';

Widget _buildTestApp({Override? authOverride}) {
  final router = GoRouter(
    initialLocation: '/profile-setup',
    routes: [
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/my-page',
        builder: (context, state) => const Scaffold(body: Text('내 페이지')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      if (authOverride != null) authOverride,
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('ProfileSetupScreen', () {
    testWidgets('AppBar 타이틀 "프로필 설정"이 표시된다', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();
      expect(find.text('프로필 설정'), findsOneWidget);
    });

    testWidgets('닉네임 TextField가 존재한다', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('"완료" 버튼이 표시된다', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();
      expect(find.text('완료'), findsOneWidget);
    });

    testWidgets('닉네임이 1자 미만이면 유효성 오류 메시지가 표시된다', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'a');
      await tester.tap(find.text('완료'));
      await tester.pumpAndSettle();

      expect(find.text('닉네임은 2자 이상이어야 합니다.'), findsOneWidget);
    });

    testWidgets('닉네임이 빈 값이면 유효성 오류 메시지가 표시된다', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('완료'));
      await tester.pumpAndSettle();

      expect(find.text('닉네임을 입력해주세요.'), findsOneWidget);
    });

    testWidgets('닉네임 2자 이상 입력 시 유효성 오류 없음', (tester) async {
      bool updateCalled = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(() => _MockAuthNotifier(
              onUpdateProfile: ({required nickname, profileImage}) async {
                updateCalled = true;
              },
            )),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/profile-setup',
              routes: [
                GoRoute(
                  path: '/profile-setup',
                  builder: (context, state) => const ProfileSetupScreen(),
                ),
                GoRoute(
                  path: '/my-page',
                  builder: (context, state) =>
                      const Scaffold(body: Text('내 페이지')),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '테스트유저');
      await tester.tap(find.text('완료'));
      await tester.pump();

      expect(find.text('닉네임을 입력해주세요.'), findsNothing);
      expect(find.text('닉네임은 2자 이상이어야 합니다.'), findsNothing);
    });

    testWidgets('프로필 이미지 CircleAvatar가 표시된다', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();
      expect(find.byType(CircleAvatar), findsOneWidget);
    });
  });
}

class _MockAuthNotifier extends AuthState {
  _MockAuthNotifier({required this.onUpdateProfile});

  final Future<void> Function({
    required String nickname,
    dynamic profileImage,
  }) onUpdateProfile;

  @override
  AsyncValue<AuthUser?> build() => const AsyncData(null);

  @override
  Future<void> updateProfile({required String nickname, dynamic profileImage}) {
    return onUpdateProfile(nickname: nickname, profileImage: profileImage);
  }
}
