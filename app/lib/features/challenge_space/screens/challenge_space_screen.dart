import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/emoji_icon.dart';
import '../../../core/widgets/invite_share_buttons.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/calendar_data.dart';
import '../providers/challenge_detail_provider.dart';
import '../providers/calendar_provider.dart';
import '../widgets/calendar_grid.dart';
import '../widgets/member_nudge_list.dart';
import '../widgets/nudge_banner.dart';

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/my-page'),
        ),
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
        actions: [
          if (detailAsync.valueOrNull != null)
            IconButton(
              icon: const EmojiIcon('💌'),
              tooltip: '초대 코드 공유',
              onPressed: () {
                final detail = detailAsync.valueOrNull!;
                showModalBottomSheet(
                  context: context,
                  builder: (ctx) => Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                    child: InviteShareButtons(
                      inviteCode: detail.inviteCode,
                      challengeTitle: detail.title,
                    ),
                  ),
                );
              },
            ),
        ],
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
          startDate: detail.startDate,
          endDate: detail.endDate,
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
  final String startDate; // YYYY-MM-DD
  final String endDate;   // YYYY-MM-DD
  final int year;
  final int month;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const _ChallengeSpaceBody({
    required this.challengeId,
    required this.startDate,
    required this.endDate,
    required this.year,
    required this.month,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  void _onDayTap(BuildContext context, String date) {
    final tapped = DateTime.parse(date);
    final start = DateTime.parse(startDate);
    final today = DateTime.now();
    final tappedDay = DateTime(tapped.year, tapped.month, tapped.day);
    final startDay = DateTime(start.year, start.month, start.day);
    final todayDay = DateTime(today.year, today.month, today.day);

    if (tappedDay.isBefore(startDay)) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: const Text('챌린지 시작 전 날짜입니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

    if (tappedDay.isAfter(todayDay)) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: const Text('아직 도래하지 않은 날짜입니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

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
          // 콕 찌르기 수신 배너
          NudgeBanner(challengeId: challengeId),
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
          const SizedBox(height: 16),
          // 멤버 목록 (탭하면 콕 찌르기)
          if (calendarAsync.valueOrNull != null)
            _MemberSection(
              challengeId: challengeId,
              calendarData: calendarAsync.valueOrNull!,
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

class _MemberSection extends ConsumerWidget {
  final String challengeId;
  final CalendarData calendarData;

  const _MemberSection({
    required this.challengeId,
    required this.calendarData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final todayDateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    DayEntry? todayEntry;
    try {
      todayEntry = calendarData.days.firstWhere((d) => d.date == todayDateStr);
    } catch (_) {
      todayEntry = null;
    }
    final currentUserId = ref.watch(authStateProvider).valueOrNull?.id;

    return MemberNudgeList(
      challengeId: challengeId,
      members: calendarData.members,
      verifiedMemberIds: todayEntry?.verifiedMembers ?? [],
      currentUserId: currentUserId,
    );
  }
}
