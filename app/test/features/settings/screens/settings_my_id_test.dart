import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:haeda/features/auth/models/auth_models.dart';
import 'package:haeda/features/auth/providers/auth_provider.dart';
import 'package:haeda/core/api/api_client.dart';
import 'package:haeda/features/settings/providers/settings_provider.dart';
import 'package:haeda/features/settings/screens/settings_screen.dart';

// Fake notifier: authStateProvider 는 NotifierProvider<AuthState, AsyncValue<AuthUser?>>
class _FakeAuth extends AuthState {
  final AuthUser? fakeUser;
  _FakeAuth(this.fakeUser);

  @override
  AsyncValue<AuthUser?> build() => AsyncData(fakeUser);
}

// 즉시 에러를 반환하는 Dio HttpClientAdapter
class _FailAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw SocketException('test mode: no network');
  }

  @override
  void close({bool force = false}) {}
}

List<Override> _buildOverrides(
  AuthUser? user,
  SharedPreferences prefs,
) {
  final fakeDio = Dio()..httpClientAdapter = _FailAdapter();
  return [
    authStateProvider.overrideWith(() => _FakeAuth(user)),
    sharedPreferencesProvider.overrideWithValue(prefs),
    dioProvider.overrideWithValue(fakeDio),
  ];
}

void main() {
  testWidgets('내 ID 행이 표시된다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: _buildOverrides(
          const AuthUser(
            id: 'u1',
            nickname: '테스트',
            discriminator: '12345',
            isNew: false,
          ),
          prefs,
        ),
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('테스트#12345'), findsOneWidget);
  });

  testWidgets('내 ID 행 탭 시 클립보드에 복사된다', (tester) async {
    final clipboardCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      clipboardCalls.add(call);
      return null;
    });

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: _buildOverrides(
          const AuthUser(
            id: 'u1',
            nickname: '테스트',
            discriminator: '12345',
            isNew: false,
          ),
          prefs,
        ),
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('my_id_row')));
    await tester.pumpAndSettle();

    final setData = clipboardCalls.firstWhere(
      (c) => c.method == 'Clipboard.setData',
      orElse: () => const MethodCall('none'),
    );
    expect(setData.method, 'Clipboard.setData');
    expect((setData.arguments as Map)['text'], '테스트#12345');

    // Clipboard mock 정리
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
}
