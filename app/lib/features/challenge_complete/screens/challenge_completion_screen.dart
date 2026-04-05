import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart';
import '../../../core/theme/season_icons.dart';
import '../models/completion_result.dart';
import '../providers/completion_provider.dart';

class ChallengeCompletionScreen extends ConsumerWidget {
  final String challengeId;

  const ChallengeCompletionScreen({super.key, required this.challengeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(completionProvider(challengeId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/my-page'),
        ),
        title: const Text('챌린지 완료'),
      ),
      body: resultAsync.when(
        loading: () => const LoadingWidget(),
        error: (error, _) => AppErrorWidget(
          error: error,
          onRetry: () => ref.invalidate(completionProvider(challengeId)),
        ),
        data: (result) => _CompletionBody(
          result: result,
          onGoHome: () => context.go('/'),
        ),
      ),
    );
  }
}

class _CompletionBody extends StatelessWidget {
  final CompletionResult result;
  final VoidCallback onGoHome;

  const _CompletionBody({required this.result, required this.onGoHome});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Center(
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.celebration, size: 28, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      '챌린지 완료!',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  result.title,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  result.category,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${result.startDate} ~ ${result.endDate}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 나의 결과
          _SectionCard(
            title: '나의 결과',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '달성률',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    Text(
                      '${result.myResult.achievementRate.toStringAsFixed(1)}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '인증 일수',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    Text(
                      '${result.myResult.verifiedDays} / ${result.myResult.expectedDays}일',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                if (result.myResult.badge != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '🏅 완료 배지 획득!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 참여자 달성률
          _SectionCard(
            title: '참여자 달성률',
            child: Column(
              children: result.members
                  .map((member) => _MemberRow(member: member))
                  .toList(),
            ),
          ),

          const SizedBox(height: 16),

          // 우리의 달력
          _SectionCard(
            title: '우리의 달력',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '전원 인증 완료',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    Text(
                      '${result.dayCompletions}일',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                if (result.calendarSummary.seasonIconTypes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: result.calendarSummary.seasonIconTypes
                        .map((type) => Text(
                              SeasonIcons.getIcon(type),
                              style: const TextStyle(fontSize: 24),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 내 페이지로 버튼
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onGoHome,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('내 페이지로'),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final MemberResult member;

  const _MemberRow({required this.member});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: member.profileImageUrl != null
                ? NetworkImage(member.profileImageUrl!)
                : null,
            child: member.profileImageUrl == null
                ? Text(
                    member.nickname.isNotEmpty
                        ? member.nickname[0]
                        : '?',
                    style: const TextStyle(fontSize: 12),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              member.nickname,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            '${member.achievementRate.toStringAsFixed(1)}%',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (member.badge != null) ...[
            const SizedBox(width: 8),
            const Text('🏅', style: TextStyle(fontSize: 16)),
          ],
        ],
      ),
    );
  }
}
