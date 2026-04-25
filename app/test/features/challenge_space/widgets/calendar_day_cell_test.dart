import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haeda/features/challenge_space/models/calendar_data.dart';
import 'package:haeda/features/challenge_space/widgets/calendar_day_cell.dart';

void main() {
  final testMembers = [
    CalendarMember(id: 'u1', nickname: '김철수', profileImageUrl: null),
    CalendarMember(id: 'u2', nickname: '이영희', profileImageUrl: null),
    CalendarMember(id: 'u3', nickname: '박지민', profileImageUrl: null),
  ];

  Widget buildCell({int day = 1, DayEntry? entry, bool isToday = false}) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 50,
          height: 60,
          child: CalendarDayCell(
            day: day,
            entry: entry,
            members: testMembers,
            isToday: isToday,
          ),
        ),
      ),
    );
  }

  group('CalendarDayCell', () {
    testWidgets('renders empty cell with day number only', (tester) async {
      await tester.pumpWidget(buildCell(day: 15));

      expect(find.text('15'), findsOneWidget);
      // No emoji or avatars
      expect(find.text('🌸'), findsNothing);
    });

    testWidgets('renders season icon when all completed', (tester) async {
      final entry = DayEntry(
        date: '2026-04-01',
        verifiedMembers: ['u1', 'u2', 'u3'],
        allCompleted: true,
        seasonIconType: 'spring',
      );

      await tester.pumpWidget(buildCell(entry: entry));

      expect(find.text('1'), findsOneWidget);
      expect(find.text('🌸'), findsOneWidget);
    });

    testWidgets('renders member thumbnails when partially verified', (tester) async {
      final entry = DayEntry(
        date: '2026-04-01',
        verifiedMembers: ['u1', 'u2'],
        allCompleted: false,
        seasonIconType: null,
      );

      await tester.pumpWidget(buildCell(entry: entry));

      expect(find.text('1'), findsOneWidget);
      // Should render CircleAvatars for verified members
      expect(find.byType(CircleAvatar), findsNWidgets(2));
    });

    testWidgets('renders season icons for each season', (tester) async {
      for (final testCase in [
        ('spring', '🌸'),
        ('summer', '🌿'),
        ('fall', '🍁'),
        ('winter', '❄️'),
      ]) {
        final entry = DayEntry(
          date: '2026-04-01',
          verifiedMembers: ['u1', 'u2', 'u3'],
          allCompleted: true,
          seasonIconType: testCase.$1,
        );

        await tester.pumpWidget(buildCell(entry: entry));
        expect(find.text(testCase.$2), findsOneWidget);
      }
    });

    testWidgets('renders today indicator when isToday is true', (tester) async {
      await tester.pumpWidget(buildCell(day: 25, isToday: true));

      expect(find.text('25'), findsOneWidget);

      // day 숫자 Text 의 가장 가까운 Container 에 primary 색 원형 decoration 이 있어야 함
      final textWidget = tester.widget<Text>(find.text('25'));
      expect(textWidget.style?.fontWeight, FontWeight.bold);

      // 원형 배지 컨테이너 검증
      final badge = tester.widget<Container>(
        find.ancestor(of: find.text('25'), matching: find.byType(Container)).first,
      );
      final decoration = badge.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, isNotNull);
    });

    testWidgets('renders today indicator above season icon when both apply', (tester) async {
      final entry = DayEntry(
        date: '2026-04-25',
        verifiedMembers: ['u1', 'u2', 'u3'],
        allCompleted: true,
        seasonIconType: 'spring',
      );

      await tester.pumpWidget(buildCell(day: 25, entry: entry, isToday: true));

      expect(find.text('25'), findsOneWidget);
      expect(find.text('🌸'), findsOneWidget);
    });
  });
}
