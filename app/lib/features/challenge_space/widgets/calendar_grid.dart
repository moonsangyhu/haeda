import 'package:flutter/material.dart';
import '../models/calendar_data.dart';
import 'calendar_day_cell.dart';

class CalendarGrid extends StatelessWidget {
  final int year;
  final int month;
  final List<DayEntry> days;
  final List<CalendarMember> members;

  const CalendarGrid({
    super.key,
    required this.year,
    required this.month,
    required this.days,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 해당 월의 1일 요일 (0=일, 1=월, ..., 6=토)
    final firstDayOfMonth = DateTime(year, month, 1);
    final startWeekday = firstDayOfMonth.weekday % 7; // DateTime: 1=월, 7=일 → 변환
    final daysInMonth = DateTime(year, month + 1, 0).day;

    // DayEntry를 날짜(day) → entry 맵으로 변환
    final dayEntryMap = <int, DayEntry>{};
    for (final entry in days) {
      final date = DateTime.parse(entry.date);
      if (date.year == year && date.month == month) {
        dayEntryMap[date.day] = entry;
      }
    }

    const weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];

    return Column(
      children: [
        // 요일 헤더
        Row(
          children: weekdayLabels.map((label) {
            final isWeekend =
                label == '일' || label == '토';
            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isWeekend
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        // 날짜 그리드
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.9,
          ),
          itemCount: startWeekday + daysInMonth,
          itemBuilder: (context, index) {
            if (index < startWeekday) {
              // 첫째 주 빈칸
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                ),
              );
            }
            final day = index - startWeekday + 1;
            return CalendarDayCell(
              day: day,
              entry: dayEntryMap[day],
              members: members,
            );
          },
        ),
      ],
    );
  }
}
