import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:haeda/main.dart' as app;

/// 시뮬레이터에서 실행되는 통합 스모크 테스트.
///
/// 명령:
///   flutter test integration_test/smoke_test.dart -d <device>
///
/// 목적:
/// - 앱이 launch 시 crash 없이 첫 화면을 띄우는지
/// - 로그인 미진행 상태이거나 자동 로그인 상태 중 하나는 정상 노출되는지
///
/// idb HID tap 이 Flutter GestureDetector 를 발화하지 못하는 한계를
/// integration_test 의 widget-tester 레벨 tap 으로 우회한다.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('앱 launch → 첫 화면 렌더', (tester) async {
    app.main();

    // IntegrationTestWidgetsFlutterBinding 은 real time 으로 동작.
    // dio 호출 / 자동 로그인 future 진행을 위해 Future.delayed + pump 반복.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    // crash 없이 Scaffold 가 1개 이상 떴으면 launch 성공으로 본다.
    // (상세 화면 검증은 위젯 테스트에서, 여기는 smoke 만.)
    expect(
      find.byType(Scaffold),
      findsAtLeastNWidgets(1),
      reason: 'Scaffold 1개 이상 렌더되어야 한다 (launch crash 없음)',
    );
  });
}
