import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:haeda/main.dart' as app;

/// 시나리오: my-page FAB → Step1 → 카테고리 '운동' 입력 → preset 이 sport 그룹으로 즉시 갱신.
///
/// 명령:
///   flutter test integration_test/step1_category_preset_test.dart -d <device>
///
/// 별도 entry file 인 이유: integration_test 는 file 단위로만 app state 격리가
/// 보장된다. 같은 file 내 다중 testWidgets 는 첫 시나리오의 navigation 상태가
/// 그대로 유지되어 두 번째 시나리오의 `app.main()` 이 my-page 로 복귀시키지 못한다.
Future<void> _settle(WidgetTester tester, {int seconds = 6}) async {
  for (var i = 0; i < seconds; i++) {
    await tester.pump(const Duration(seconds: 1));
    await Future<void>.delayed(const Duration(seconds: 1));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'my-page FAB → Step1 → 카테고리 "운동" 입력 → sport preset 갱신',
    (tester) async {
      app.main();
      await _settle(tester);

      // (Step 1) FAB 노출 + 탭 → Step1 진입.
      expect(find.byType(FloatingActionButton), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await _settle(tester, seconds: 3);

      // (Step 2) Step1 의 emoji preset wrap + universal 기본 노출.
      expect(find.byKey(const Key('emoji_preset_wrap')), findsOneWidget);
      // universal preset 에는 '🏋️' 가 없다 → 미노출.
      expect(find.byKey(const Key('emoji_preset_🏋️')), findsNothing);

      // (Step 3) 카테고리 '운동' 입력 → preset 이 sport 로 즉시 갱신.
      await tester.enterText(
        find.byKey(const Key('category_field')),
        '운동',
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('emoji_preset_🏋️')), findsOneWidget);
      expect(find.byKey(const Key('emoji_preset_💪')), findsOneWidget);
    },
  );
}
