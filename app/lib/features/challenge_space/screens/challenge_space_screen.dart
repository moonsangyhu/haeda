import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart';
import '../models/calendar_data.dart';
import '../providers/challenge_detail_provider.dart';
import '../providers/calendar_provider.dart';
import '../widgets/calendar_grid.dart';

class ChallengeSpaceScreen extends ConsumerStatefulWidget {
  final String challengeId;

  const ChallengeSpaceScreen({super.key, required this.challengeId});

  @override
  ConsumerState<ChallengeSpaceScreen> createState() =>
      _ChallengeSpaceScreenState();
}

class _ChallengeSpaceScreenState
    extends ConsumerState<ChallengeSpaceScreen> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  void _previousMonth() {
    setState(() {
      if (_month == 1) {
        _year--;
        _month = 12;
      } else {
        _month--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_month == 12) {
        _year++;
        _month = 1;
      } else {
        _month++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync =
        ref.watch(challengeDetailProvider(widget.challengeId));

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: detailAsync.when(
          loading: () => const Text('챌린지'),
          error: (_, __) => const Text('챌린지'),
          data: (detail) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                detail.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '참여자 ${detail.memberCount}명',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
      body: detailAsync.when(
        loading: () => const LoadingWidget(),
        error: (error, _) => AppErrorWidget(
          error: error,
          onRetry: () =>
              ref.invalidate(challengeDetailProvider(widget.challengeId)),
        ),
        data: (detail) => _ChallengeSpaceBody(
          challengeId: widget.challengeId,
          year: _year,
          month: _month,
          onPreviousMonth: _previousMonth,
          onNextMonth: _nextMonth,
        ),
      ),
    );
  }
}

class _ChallengeSpaceBody extends ConsumerWidget {
  final String challengeId;
  final int year;
  final int month;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const _ChallengeSpaceBody({
    required this.challengeId,
    required this.year,
    required this.month,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  void _onDayTap(BuildContext context, String date) {
    context.push('/challenges/$challengeId/verifications/$date');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = CalendarParams(
      challengeId: challengeId,
      year: year,
      month: month,
    );
    final calendarAsync = ref.watch(calendarProvider(params));
    final now = DateTime.now();

    return SingleChildScrollView(
      child: Column(
        children: [
          // 월 네비게이터
          _MonthNavigator(
            year: year,
            month: month,
            onPrevious: onPreviousMonth,
            onNext: onNextMonth,
          ),
          const Divider(height: 1),
          // 달력 그리드
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: calendarAsync.when(
              loading: () => const SizedBox(
                height: 300,
                child: LoadingWidget(),
              ),
              error: (error, _) => SizedBox(
                height: 300,
                child: AppErrorWidget(error: error),
              ),
              data: (calendarData) => CalendarGrid(
                year: year,
                month: month,
                days: calendarData.days,
                members: calendarData.members,
                onDayTap: (date) => _onDayTap(context, date),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 오늘 섹션
          _TodaySection(
            now: now,
            calendarData: calendarAsync.valueOrNull,
            challengeId: challengeId,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MonthNavigator extends StatelessWidget {
  final int year;
  final int month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthNavigator({
    required this.year,
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
            tooltip: '이전 달',
          ),
          Text(
            '$year년 $month월',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
            tooltip: '다음 달',
          ),
        ],
      ),
    );
  }
}

class _TodaySection extends StatelessWidget {
  final DateTime now;
  final CalendarData? calendarData;
  final String challengeId;

  const _TodaySection({
    required this.now,
    required this.challengeId,
    this.calendarData,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 오늘 인증 여부 확인
    String todayDateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    DayEntry? todayEntry;
    if (calendarData != null) {
      try {
        todayEntry = calendarData!.days.firstWhere(
          (d) => d.date == todayDateStr,
        );
      } catch (_) {
        todayEntry = null;
      }
    }

    final verifiedToday =
        todayEntry != null && todayEntry.verifiedMembers.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Divider(color: theme.colorScheme.outline)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '오늘 (${now.month}월 ${now.day}일)',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(child: Divider(color: theme.colorScheme.outline)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            verifiedToday ? '오늘 인증 완료!' : '아직 인증하지 않았어요!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: verifiedToday
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: verifiedToday
                ? null
                : () => context.push('/challenges/$challengeId/verify'),
            child: Text(verifiedToday ? '인증 완료' : '인증하기'),
          ),
        ],
      ),
    );
  }
}
