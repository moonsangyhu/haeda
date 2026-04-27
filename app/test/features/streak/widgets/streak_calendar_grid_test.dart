import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haeda/features/streak/models/day_status.dart';
import 'package:haeda/features/streak/models/streak_calendar.dart';
import 'package:haeda/features/streak/widgets/streak_calendar_grid.dart';

StreakCalendar _calendar({
  int year = 2026,
  int month = 4,
  List<StreakDay>? days,
}) {
  final daysList = days ??
      [
        StreakDay(date: DateTime(2026, 4, 1), status: DayStatus.success),
        StreakDay(date: DateTime(2026, 4, 2), status: DayStatus.failure),
        StreakDay(date: DateTime(2026, 4, 27), status: DayStatus.todayPending),
        StreakDay(date: DateTime(2026, 4, 30), status: DayStatus.future),
      ];
  return StreakCalendar(
    streak: 1,
    firstJoinDate: DateTime(2026, 4, 1),
    year: year,
    month: month,
    days: daysList,
  );
}

bool _hasSvgWith(WidgetTester tester, String assetSubstring) {
  return tester.widgetList<SvgPicture>(find.byType(SvgPicture)).any(
        (s) => s.bytesLoader.toString().contains(assetSubstring),
      );
}

void main() {
  testWidgets('renders fire.svg for success cells', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StreakCalendarGrid(
            calendar: _calendar(),
            onPrevMonth: () {},
            onNextMonth: () {},
          ),
          ),
        ),
      ),
    );
    expect(_hasSvgWith(tester, 'fire.svg'), isTrue);
  });

  testWidgets('renders ice.svg for failure cells', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StreakCalendarGrid(
            calendar: _calendar(),
            onPrevMonth: () {},
            onNextMonth: () {},
          ),
          ),
        ),
      ),
    );
    expect(_hasSvgWith(tester, 'ice.svg'), isTrue);
  });

  testWidgets('next-month arrow disabled when on current month', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StreakCalendarGrid(
            calendar: _calendar(year: now.year, month: now.month),
            onPrevMonth: () {},
            onNextMonth: () {},
          ),
          ),
        ),
      ),
    );
    final nextBtn = tester.widget<IconButton>(
      find.byKey(const Key('streak-next-month')),
    );
    expect(nextBtn.onPressed, isNull);
  });

  testWidgets('prev-month arrow always enabled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StreakCalendarGrid(
            calendar: _calendar(),
            onPrevMonth: () {},
            onNextMonth: () {},
          ),
          ),
        ),
      ),
    );
    final prevBtn = tester.widget<IconButton>(
      find.byKey(const Key('streak-prev-month')),
    );
    expect(prevBtn.onPressed, isNotNull);
  });
}
