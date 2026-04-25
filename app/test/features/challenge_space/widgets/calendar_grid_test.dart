import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haeda/features/challenge_space/models/calendar_data.dart';
import 'package:haeda/features/challenge_space/widgets/calendar_day_cell.dart';
import 'package:haeda/features/challenge_space/widgets/calendar_grid.dart';

void main() {
  final testMembers = [
    CalendarMember(id: 'u1', nickname: '김철수', profileImageUrl: null),
  ];

  Widget buildGrid({required int year, required int month}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CalendarGrid(
            year: year,
            month: month,
            days: const [],
            members: testMembers,
          ),
        ),
      ),
    );
  }

  group('CalendarGrid', () {
    testWidgets('marks exactly today cell with isToday when current month', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(buildGrid(year: now.year, month: now.month));

      final cells = tester.widgetList<CalendarDayCell>(find.byType(CalendarDayCell));
      final todayCells = cells.where((c) => c.isToday).toList();

      expect(todayCells.length, 1);
      expect(todayCells.first.day, now.day);
    });

    testWidgets('marks no cell with isToday when not current month', (tester) async {
      final now = DateTime.now();
      // 다음 달 (12월이면 다음 해 1월)
      final nextMonth = now.month == 12 ? 1 : now.month + 1;
      final nextYear = now.month == 12 ? now.year + 1 : now.year;

      await tester.pumpWidget(buildGrid(year: nextYear, month: nextMonth));

      final cells = tester.widgetList<CalendarDayCell>(find.byType(CalendarDayCell));
      final todayCells = cells.where((c) => c.isToday).toList();

      expect(todayCells.length, 0);
    });
  });
}
