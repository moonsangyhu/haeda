import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart';
import '../models/challenge_summary.dart';
import '../providers/my_challenges_provider.dart';
import '../widgets/challenge_card.dart';
import '../../auth/providers/auth_provider.dart';

class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengesAsync = ref.watch(myChallengesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 페이지'),
        centerTitle: false,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton(
          onPressed: () => context.push('/create'),
          tooltip: '챌린지 만들기',
          child: const Icon(Icons.add),
        ),
      ),
      body: challengesAsync.when(
        loading: () => const LoadingWidget(),
        error: (error, _) => AppErrorWidget(
          error: error,
          onRetry: () => ref.invalidate(myChallengesProvider),
        ),
        data: (challenges) => _ChallengeList(challenges: challenges),
      ),
    );
  }
}

class _ChallengeList extends StatelessWidget {
  final List<ChallengeSummary> challenges;

  const _ChallengeList({required this.challenges});

  @override
  Widget build(BuildContext context) {
    final active =
        challenges.where((c) => c.status == 'active').toList();
    final completed =
        challenges.where((c) => c.status == 'completed').toList();

    return ListView(
      children: [
        const _MyIdHeader(),
        if (challenges.isEmpty) ...[
          const SizedBox(height: 40),
          const Center(
            child: Text('참여 중인 챌린지가 없습니다.'),
          ),
        ],
        if (active.isNotEmpty) ...[
          const _SectionHeader(title: '참여 중인 챌린지'),
          ...active.map(
            (c) => ChallengeCard(
              challenge: c,
              onTap: () => context.go('/challenges/${c.id}'),
            ),
          ),
        ],
        if (completed.isNotEmpty) ...[
          const _SectionHeader(title: '완료된 챌린지'),
          ...completed.map(
            (c) => ChallengeCard(
              challenge: c,
              onTap: () => context.go('/challenges/${c.id}'),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _MyIdHeader extends ConsumerWidget {
  const _MyIdHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null ||
        user.nickname == null ||
        user.discriminator == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final fullId = '${user.nickname}#${user.discriminator}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: GestureDetector(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: fullId));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ID 복사됨')),
          );
        },
        child: Row(
          children: [
            Text(
              user.nickname!,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '#${user.discriminator}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.copy,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
