import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/user_stats.dart';
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

class _StatusBarContent extends StatelessWidget {
  const _StatusBarContent({required this.stats});

  final UserStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final streakAsset = stats.verifiedToday ? 'fire' : 'sleep';
    final isDark = theme.brightness == Brightness.dark;
    final pillOpacity = isDark ? 0.10 : 0.15;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: theme.scaffoldBackgroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Semantics(
                label: '스트릭 ${stats.streak}일, 오늘 인증 ${stats.verifiedToday ? "완료" : "미완료"}',
                excludeSemantics: true,
                child: _StatPill(
                  color: const Color(0xFFFF6B35),
                  opacity: pillOpacity,
                  child: _StatItem(
                    asset: streakAsset,
                    value: '${stats.streak}',
                  ),
                ),
              ),
              Semantics(
                label: '활성 챌린지 ${stats.activeChallenges}개, 완료 ${stats.completedChallenges}개',
                excludeSemantics: true,
                child: _StatPill(
                  color: const Color(0xFFFFB800),
                  opacity: pillOpacity,
                  child: _StatItem(
                    asset: 'lightning',
                    value: '${stats.activeChallenges}/${stats.completedChallenges}',
                  ),
                ),
              ),
              Semantics(
                label: '젬 ${stats.gems}개',
                excludeSemantics: true,
                child: _StatPill(
                  color: const Color(0xFF4FC3F7),
                  opacity: pillOpacity,
                  child: _StatItem(
                    asset: 'gem',
                    value: '${stats.gems}',
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
    required this.asset,
    required this.value,
  });

  final String asset;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
