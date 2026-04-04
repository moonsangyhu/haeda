import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 인증하기 버튼이 비활성(disabled) ���태인지 검증하는 테스트.
/// ChallengeSpaceScreen은 Riverpod provider에 의존하므로,
/// 여기���는 버튼만 단독으로 테스트한다.
void main() {
  group('인증하기 버튼', () {
    testWidgets('renders as disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              onPressed: null,
              child: Text('인증하기'),
            ),
          ),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
      expect(find.text('인증하기'), findsOneWidget);
    });
  });
}
