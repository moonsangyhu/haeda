import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haeda/features/streak/widgets/streak_header.dart';

void main() {
  testWidgets('renders streak number large + label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StreakHeader(streak: 14)),
      ),
    );

    expect(find.text('14'), findsOneWidget);
    expect(find.text('일 연속'), findsOneWidget);
  });

  testWidgets('renders 0 streak correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StreakHeader(streak: 0)),
      ),
    );
    expect(find.text('0'), findsOneWidget);
    expect(find.text('일 연속'), findsOneWidget);
  });
}
