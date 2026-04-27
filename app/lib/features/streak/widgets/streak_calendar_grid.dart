import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/day_status.dart';
import '../models/streak_calendar.dart';

class StreakCalendarGrid extends StatelessWidget {
  const StreakCalendarGrid({
    super.key,
    required this.calendar,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  final StreakCalendar calendar;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentOrFuture = calendar.year > now.year ||
        (calendar.year == now.year && calendar.month >= now.month);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MonthNav(
          year: calendar.year,
          month: calendar.month,
          onPrev: onPrevMonth,
          onNext: isCurrentOrFuture ? null : onNextMonth,
        ),
        const SizedBox(height: 8),
        const _WeekHeader(),
        const SizedBox(height: 4),
        _Grid(calendar: calendar),
      ],
    );
  }
}

class _MonthNav extends StatelessWidget {
  const _MonthNav({
    required this.year,
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  final int year;
  final int month;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          key: const Key('streak-prev-month'),
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left),
        ),
        SizedBox(
          width: 140,
          child: Text(
            '$year년 $month월',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          key: const Key('streak-next-month'),
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader();

  @override
  Widget build(BuildContext context) {
    const labels = ['일', '월', '화', '수', '목', '금', '토'];
    return Row(
      children: labels
          .map(
            (l) => Expanded(
              child: Center(
                child: Text(
                  l,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.calendar});

  final StreakCalendar calendar;

  @override
  Widget build(BuildContext context) {
    final byDay = {for (final d in calendar.days) d.date.day: d};
    final firstWeekday =
        DateTime(calendar.year, calendar.month, 1).weekday % 7;
    final today = DateTime.now();

    final cells = <Widget>[];
    for (var i = 0; i < firstWeekday; i++) {
      cells.add(const _EmptyCell());
    }
    for (var d = 1; d <= calendar.days.length; d++) {
      final entry = byDay[d];
      final dt = DateTime(calendar.year, calendar.month, d);
      final isToday = dt.year == today.year &&
          dt.month == today.month &&
          dt.day == today.day;
      cells.add(_DayCell(day: d, entry: entry, isToday: isToday));
    }
    while (cells.length < 42) {
      cells.add(const _EmptyCell());
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1,
      children: cells,
    );
  }
}

class _EmptyCell extends StatelessWidget {
  const _EmptyCell();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.entry,
    required this.isToday,
  });

  final int day;
  final StreakDay? entry;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = entry?.status ?? DayStatus.future;
    final dim = status == DayStatus.future || status == DayStatus.beforeJoin;

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: isToday
            ? Border.all(color: theme.colorScheme.primary, width: 2)
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: theme.textTheme.bodySmall?.copyWith(
              color: dim
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                  : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          _statusIcon(status),
        ],
      ),
    );
  }

  Widget _statusIcon(DayStatus status) {
    switch (status) {
      case DayStatus.success:
        return SvgPicture.asset('assets/icons/fire.svg', width: 16, height: 16);
      case DayStatus.failure:
        return SvgPicture.asset('assets/icons/ice.svg', width: 16, height: 16);
      case DayStatus.todayPending:
      case DayStatus.future:
      case DayStatus.beforeJoin:
        return const SizedBox(width: 16, height: 16);
    }
  }
}
