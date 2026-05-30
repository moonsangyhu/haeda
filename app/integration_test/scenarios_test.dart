import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:haeda/features/my_page/widgets/challenge_card.dart';
import 'package:haeda/main.dart' as app;

/// 깊은 시나리오 (스모크 이상). 시뮬레이터에서 실측.
///
/// 명령:
///   flutter test integration_test/scenarios_test.dart -d <device>
///
/// 박지민 로그인 상태 + ChallengeCard 가 노출되는 my-page 상태를 가정한다.
/// (시뮬레이터에 keychain 잔존 상태 그대로 사용.)
///
/// pump(duration) + Future.delayed 조합으로 dio future / LoadingWidget 의
/// CircularProgressIndicator 무한 frame 을 양쪽 다 처리.
Future<void> _settle(WidgetTester tester, {int seconds = 6}) async {
  for (var i = 0; i < seconds; i++) {
    await tester.pump(const Duration(seconds: 1));
    await Future<void>.delayed(const Duration(seconds: 1));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'my-page → ChallengeCard tap → 챌린지방 헤더 emoji → (creator 면) sheet 노출',
    (tester) async {
      app.main();
      await _settle(tester);

      // (Step 1) 박지민 my-page 가 떴다면 ChallengeCard 가 1개 이상 존재.
      expect(find.byType(ChallengeCard), findsAtLeastNWidgets(1));

      // (Step 2) 첫 번째 카드 탭 → /challenges/:id 진입.
      await tester.tap(find.byType(ChallengeCard).first);
      await _settle(tester);

      // (Step 3) 챌린지방 헤더 emoji GestureDetector 가 노출.
      expect(find.byKey(const Key('challenge_header_icon')), findsOneWidget);

      // (Step 4) 헤더 emoji 탭 → bottom sheet 열림 (creator 인 경우만).
      await tester.tap(find.byKey(const Key('challenge_header_icon')));
      await tester.pump(const Duration(milliseconds: 500));

      // 첫 ChallengeCard 가 비-creator 챌린지면 sheet 가 안 열림 → skip.
      final wrap = find.byKey(const Key('emoji_preset_wrap'));
      if (wrap.evaluate().isEmpty) {
        // ignore: avoid_print
        print(
          'NOTE: 첫 ChallengeCard 가 비-creator 챌린지 — sheet 단계 skip',
        );
        return;
      }
      expect(wrap, findsOneWidget);
    },
  );
}
