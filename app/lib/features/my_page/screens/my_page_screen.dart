import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart';
import '../models/challenge_summary.dart';
import '../providers/my_challenges_provider.dart';
import '../widgets/challenge_card.dart';

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
        // Flow 2: [챌린지 만들기] 버튼 — 프로필 영역 아래, 챌린지 목록 위에 위치
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: FilledButton.icon(
            key: const Key('create_challenge_button'),
            onPressed: () => context.go('/create'),
            icon: const Icon(Icons.add),
            label: const Text('챌린지 만들기'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
        if (challenges.isEmpty) ...[
          const SizedBox(height: 40),
          const Center(
            child: Text('참여 중인 챌린지가 없습니다.'),
          ),
        ],
        if (active.isNotEmpty) ...[
          _SectionHeader(title: '참여 중인 챌린지'),
          ...active.map(
            (c) => ChallengeCard(
              challenge: c,
              onTap: () => context.go('/challenges/${c.id}'),
            ),
          ),
        ],
        if (completed.isNotEmpty) ...[
          _SectionHeader(title: '완료된 챌린지'),
          ...completed.map(
            (c) => ChallengeCard(
              challenge: c,
              onTap: () => context.go('/challenges/${c.id}/completion'),
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
