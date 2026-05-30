import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:haeda/core/api/api_client.dart';
import 'package:haeda/features/challenge_space/models/calendar_data.dart';
import 'package:haeda/features/challenge_space/models/challenge_detail.dart';
import 'package:haeda/features/challenge_space/providers/calendar_provider.dart';
import 'package:haeda/features/challenge_space/providers/challenge_detail_provider.dart';
import 'package:haeda/features/challenge_space/providers/nudge_provider.dart';
import 'package:haeda/features/challenge_space/screens/challenge_space_screen.dart';
import 'package:haeda/features/notifications/models/notification_data.dart';

class _PendingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      Completer<ResponseBody>().future;

  @override
  void close({bool force = false}) {}
}

Dio _pendingDio() {
  final dio = Dio();
  dio.httpClientAdapter = _PendingAdapter();
  return dio;
}

ChallengeDetail _detail({String icon = '🎯', bool isCreator = true}) {
  return ChallengeDetail(
    id: 'c1',
    title: '운동 30일',
    description: null,
    category: '운동',
    startDate: '2026-05-01',
    endDate: '2026-05-30',
    verificationFrequency: const {'type': 'daily'},
    photoRequired: false,
    dayCutoffHour: 0,
    inviteCode: 'ABCD1234',
    status: 'active',
    creator: const MemberBrief(id: 'u1', nickname: '테스터'),
    memberCount: 1,
    isMember: true,
    isCreator: isCreator,
    icon: icon,
    createdAt: '2026-05-01T00:00:00Z',
  );
}

Widget _wrap({
  required String challengeId,
  required ChallengeDetail detail,
}) {
  final router = GoRouter(
    initialLocation: '/challenges/$challengeId',
    routes: [
      GoRoute(
        path: '/my-page',
        builder: (_, __) => const Scaffold(body: Text('my-page')),
      ),
      GoRoute(
        path: '/challenges/:id',
        builder: (_, state) => ChallengeSpaceScreen(
          challengeId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(_pendingDio()),
      challengeDetailProvider(challengeId).overrideWith(
        (ref) async => detail,
      ),
      calendarProvider.overrideWith(
        (ref, params) => Completer<CalendarData>().future,
      ),
      receivedNudgesProvider.overrideWith(
        (ref, id) => Completer<List<NotificationItem>>().future,
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('AppBar 에 detail.icon 이 노출된다', (tester) async {
    await tester.pumpWidget(
      _wrap(challengeId: 'c1', detail: _detail(icon: '🏃', isCreator: true)),
    );
    await tester.pump();
    expect(find.text('🏃'), findsOneWidget);
  });

  testWidgets('creator 가 헤더 이모지 탭 시 EmojiEditSheet 가 열린다', (tester) async {
    await tester.pumpWidget(
      _wrap(challengeId: 'c1', detail: _detail(icon: '🏃', isCreator: true)),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('challenge_header_icon')));
    // body 의 LoadingWidget 이 frame 무한 schedule 하므로 pumpAndSettle 대신
    // 모달 애니메이션이 끝날 만한 짧은 시간만 진행.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('emoji_preset_wrap')), findsOneWidget);
  });

  testWidgets('비-creator 가 헤더 이모지 탭 시 sheet 가 열리지 않는다', (tester) async {
    await tester.pumpWidget(
      _wrap(challengeId: 'c1', detail: _detail(icon: '🏃', isCreator: false)),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('challenge_header_icon')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('emoji_preset_wrap')), findsNothing);
  });
}
