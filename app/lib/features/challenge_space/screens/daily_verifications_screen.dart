import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/season_icons.dart';
import '../../../core/widgets/error_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/verification_data.dart';
import '../providers/verification_provider.dart';

class DailyVerificationsScreen extends ConsumerWidget {
  final String challengeId;
  final String date; // YYYY-MM-DD

  const DailyVerificationsScreen({
    super.key,
    required this.challengeId,
    required this.date,
  });

  String _formatDate(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr);
      return '${parsed.month}월 ${parsed.day}일';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = DailyVerificationParams(
      challengeId: challengeId,
      date: date,
    );
    final dailyAsync = ref.watch(dailyVerificationsProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: Text('${_formatDate(date)} 인증 현황'),
        leading: const BackButton(),
      ),
      body: dailyAsync.when(
        loading: () => const LoadingWidget(),
        error: (error, _) => AppErrorWidget(
          error: error,
          onRetry: () => ref.invalidate(dailyVerificationsProvider(params)),
        ),
        data: (data) => _DailyVerificationsBody(data: data),
      ),
    );
  }
}

class _DailyVerificationsBody extends StatelessWidget {
  final DailyVerifications data;

  const _DailyVerificationsBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = data.verifications.length;

    return ListView(
      children: [
        // 상단 요약 섹션
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: data.allCompleted
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
          ),
          child: Column(
            children: [
              if (data.allCompleted) ...[
                Text(
                  SeasonIcons.getIcon(data.seasonIconType),
                  style: const TextStyle(fontSize: 40),
                ),
                const SizedBox(height: 8),
                Text(
                  '전원 인증 완료!',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ] else
                Text(
                  '인증 현황',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                '$total명 인증',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: data.allCompleted
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // 인증자 리스트
        if (data.verifications.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('아직 인증한 사람이 없습니다.')),
          )
        else
          ...data.verifications.map(
            (item) => _VerificationListItem(item: item),
          ),
      ],
    );
  }
}

class _VerificationListItem extends StatelessWidget {
  final VerificationItem item;

  const _VerificationListItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: () => context.push('/verifications/${item.id}'),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: theme.colorScheme.primaryContainer,
        backgroundImage: item.user.profileImageUrl != null
            ? NetworkImage(item.user.profileImageUrl!)
            : null,
        child: item.user.profileImageUrl == null
            ? Text(
                item.user.nickname.isNotEmpty
                    ? item.user.nickname[0]
                    : '?',
                style: const TextStyle(fontSize: 14),
              )
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.user.nickname,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Icon(
            Icons.check_circle,
            color: theme.colorScheme.primary,
            size: 18,
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.diaryText.isNotEmpty)
            Text(
              item.diaryText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.comment_outlined,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${item.commentCount}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}
