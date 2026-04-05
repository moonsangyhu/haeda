import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haeda/core/widgets/invite_share_buttons.dart';

void main() {
  const testInviteCode = 'ABCD1234';

  Widget buildWidget({String? challengeTitle}) {
    return MaterialApp(
      home: Scaffold(
        body: InviteShareButtons(
          inviteCode: testInviteCode,
          challengeTitle: challengeTitle,
        ),
      ),
    );
  }

  testWidgets('코드 복사 버튼이 렌더링된다', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('copy_code_button')), findsOneWidget);
    expect(find.text('코드 복사'), findsOneWidget);
  });

  testWidgets('카카오톡 공유 버튼이 렌더링된다', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kakao_share_button')), findsOneWidget);
    expect(find.text('카카오톡으로 공유'), findsOneWidget);
  });

  testWidgets('challengeTitle이 전달되어도 정상 렌더링된다', (tester) async {
    await tester.pumpWidget(buildWidget(challengeTitle: '운동 30일'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('copy_code_button')), findsOneWidget);
    expect(find.byKey(const Key('kakao_share_button')), findsOneWidget);
  });
}
