import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/season_icons.dart';
import '../../../core/widgets/character_avatar.dart';
import '../../../core/widgets/error_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../../character/providers/character_provider.dart';
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: dailyAsync.when(
        loading: () => const LoadingWidget(),
        error: (error, _) => AppErrorWidget(
          error: error,
          onRetry: () => ref.invalidate(dailyVerificationsProvider(params)),
        ),
        data: (data) {
          final currentUser = ref.watch(authStateProvider).valueOrNull;
          final currentUserId = currentUser?.id;
          // 현재 유저가 해당 날짜에 인증했는지 확인
          final hasVerified = currentUserId != null &&
              data.verifications.any((v) => v.user.id == currentUserId);
          // 오늘 이전 날짜인지 확인 (오늘 포함 — 오늘은 챌린지 공간에서 인증)
          final parsedDate = DateTime.tryParse(date);
          final today = DateTime.now();
          final isPastDate = parsedDate != null &&
              DateTime(parsedDate.year, parsedDate.month, parsedDate.day)
                  .isBefore(DateTime(today.year, today.month, today.day));
          final canVerify = !hasVerified && isPastDate;

          return _DailyVerificationsBody(
            data: data,
            challengeId: challengeId,
            date: date,
            canVerify: canVerify,
          );
        },
      ),
    );
  }
}

class _DailyVerificationsBody extends StatelessWidget {
  final DailyVerifications data;
  final String challengeId;
  final String date;
  final bool canVerify;

  const _DailyVerificationsBody({
    required this.data,
    required this.challengeId,
    required this.date,
    required this.canVerify,
  });

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
        // 과거 날짜 인증하기 버튼
        if (canVerify)
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () => context.push(
                '/challenges/$challengeId/verify?date=$date',
              ),
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('이 날짜에 인증하기'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
      ],
    );
  }
}

class _VerificationListItem extends ConsumerWidget {
  final VerificationItem item;

  const _VerificationListItem({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    final character = (myId != null && myId == item.user.id)
        ? ref.watch(myCharacterProvider).valueOrNull ?? item.user.character
        : item.user.character;

    return ListTile(
      onTap: () => context.push('/verifications/${item.id}'),
      leading: CharacterAvatar(
        character: character,
        size: 44,
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
          Icon(Icons.check_circle, size: 14, color: Theme.of(context).colorScheme.primary),
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
          if (item.commentCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              '💬 ${item.commentCount}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}
