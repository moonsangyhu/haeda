import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../my_page/models/challenge_summary.dart';
import '../models/user_stats.dart';
import '../providers/most_recent_challenge_provider.dart';
import '../providers/user_stats_provider.dart';

class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(userStatsProvider);

    return statsAsync.when(
      loading: () => const SizedBox(height: 44),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) => _StatusBarContent(stats: stats),
    );
  }
}

class _StatusBarContent extends ConsumerWidget {
  const _StatusBarContent({required this.stats});

  final UserStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final streakAsset = stats.verifiedToday ? 'fire' : 'sleep';
    final isDark = theme.brightness == Brightness.dark;
    final pillOpacity = isDark ? 0.10 : 0.15;
    final mostRecent = ref.watch(mostRecentChallengeProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: theme.scaffoldBackgroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => context.push('/streak'),
                  borderRadius: BorderRadius.circular(14),
                  child: Semantics(
                    label:
                        '스트릭 ${stats.streak}일, 오늘 인증 ${stats.verifiedToday ? "완료" : "미완료"}',
                    excludeSemantics: true,
                    button: true,
                    child: _StatPill(
                      color: const Color(0xFFFF6B35),
                      opacity: pillOpacity,
                      child: _StatItem(
                        asset: streakAsset,
                        value: '${stats.streak}',
                      ),
                    ),
                  ),
                ),
              ),
              _ChallengePill(
                stats: stats,
                mostRecent: mostRecent,
                pillOpacity: pillOpacity,
              ),
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => context.push('/gems'),
                  borderRadius: BorderRadius.circular(14),
                  child: Semantics(
                    label: '젬 ${stats.gems}개',
                    excludeSemantics: true,
                    button: true,
                    child: _StatPill(
                      color: const Color(0xFF4FC3F7),
                      opacity: pillOpacity,
                      child: _StatItem(
                        asset: 'gem',
                        value: '${stats.gems}',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: theme.colorScheme.outline.withValues(alpha: 0.4),
        ),
      ],
    );
  }
}

class _ChallengePill extends StatelessWidget {
  const _ChallengePill({
    required this.stats,
    required this.mostRecent,
    required this.pillOpacity,
  });

  final UserStats stats;
  final ChallengeSummary? mostRecent;
  final double pillOpacity;

  @override
  Widget build(BuildContext context) {
    final hasChallenge = mostRecent != null;
    final tapTarget = hasChallenge
        ? '/challenges/${mostRecent!.id}'
        : '/create';
    final semanticsLabel = hasChallenge
        ? '챌린지 ${mostRecent!.title}, 진행 중 ${stats.activeChallenges}개'
        : '챌린지 없음, 만들기';

    final item = hasChallenge
        ? _StatItem(emoji: mostRecent!.icon, value: '${stats.activeChallenges}')
        : _StatItem(asset: 'lightning', value: '${stats.activeChallenges}');

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const Key('challenge_pill'),
        onTap: () => context.push(tapTarget),
        borderRadius: BorderRadius.circular(14),
        child: Semantics(
          label: semanticsLabel,
          excludeSemantics: true,
          button: true,
          child: _StatPill(
            color: const Color(0xFFFFB800),
            opacity: pillOpacity,
            child: item,
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.color,
    required this.opacity,
    required this.child,
  });

  final Color color;
  final double opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    this.asset,
    this.emoji,
    required this.value,
  }) : assert(asset != null || emoji != null,
            'asset 또는 emoji 중 하나는 반드시 지정');

  final String? asset;
  final String? emoji;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (emoji != null)
          Text(
            emoji!,
            style: const TextStyle(fontSize: 18),
          )
        else
          SvgPicture.asset(
            'assets/icons/$asset.svg',
            width: 20,
            height: 20,
          ),
        const SizedBox(width: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
