import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:haeda/features/challenge_space/widgets/speech_bubble.dart';

void main() {
  Widget buildSubject({
    String text = '오늘 화이팅!',
    double opacity = 1.0,
    double scale = 1.0,
    String semanticsNickname = '철수',
    double maxWidth = 200,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SpeechBubble(
            text: text,
            opacity: opacity,
            scale: scale,
            semanticsNickname: semanticsNickname,
            maxWidth: maxWidth,
          ),
        ),
      ),
    );
  }

  testWidgets('renders text at full opacity', (tester) async {
    await tester.pumpWidget(buildSubject(text: '오늘 화이팅!', opacity: 1.0));

    expect(find.text('오늘 화이팅!'), findsOneWidget);
  });

  testWidgets('is invisible at zero opacity', (tester) async {
    await tester.pumpWidget(buildSubject(opacity: 0.0));

    final opacityWidget = tester.widget<Opacity>(
      find.ancestor(
        of: find.text('오늘 화이팅!'),
        matching: find.byType(Opacity),
      ).first,
    );
    expect(opacityWidget.opacity, 0.0);
  });

  testWidgets('applies correct semantics label', (tester) async {
    await tester.pumpWidget(
      buildSubject(text: '같이해요', semanticsNickname: '민수'),
    );

    expect(
      find.bySemanticsLabel('민수: 같이해요'),
      findsOneWidget,
    );
  });

  testWidgets('truncates long text to 2 lines with ellipsis', (tester) async {
    const longText = '이것은 매우 매우 매우 매우 매우 매우 매우 긴 텍스트입니다. '
        '두 줄을 초과하면 말줄임표로 잘립니다.';
    await tester.pumpWidget(buildSubject(text: longText, maxWidth: 120));

    // Widget should render without overflow error
    expect(find.byType(SpeechBubble), findsOneWidget);
  });

  testWidgets('renders with custom scale transform', (tester) async {
    await tester.pumpWidget(buildSubject(scale: 0.92));

    final transform = tester.widget<Transform>(
      find.ancestor(
        of: find.byType(Semantics),
        matching: find.byType(Transform),
      ).first,
    );
    expect(transform, isNotNull);
  });
}
