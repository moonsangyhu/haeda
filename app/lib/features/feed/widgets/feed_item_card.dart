import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../models/feed_item_data.dart';
import '../providers/feed_provider.dart';

class FeedItemCard extends ConsumerWidget {
  const FeedItemCard({super.key, required this.item});

  final FeedItemData item;

  String _timeAgo(String createdAt) {
    try {
      final created = DateTime.parse(createdAt).toLocal();
      final now = DateTime.now();
      final diff = now.difference(created);
      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
      if (diff.inHours < 24) return '${diff.inHours}시간 전';
      if (diff.inDays < 7) return '${diff.inDays}일 전';
      return '${created.month}월 ${created.day}일';
    } catch (_) {
      return '';
    }
  }

  String _activityDescription() {
    switch (item.type) {
      case 'verification':
        return '${item.actor.nickname}님이 ${item.challengeTitle}에 인증했어요';
      case 'challenge_join':
        return '${item.actor.nickname}님이 ${item.challengeTitle}에 참여했어요';
      case 'challenge_complete':
        return '${item.actor.nickname}님이 ${item.challengeTitle}을 완주했어요! 🎉';
      default:
        return '${item.actor.nickname}님의 새로운 소식';
    }
  }

  Future<void> _onClapTap(WidgetRef ref) async {
    try {
      final dio = ref.read(dioProvider);
      await toggleClap(dio, item.id);
      ref.invalidate(feedListProvider);
    } on DioException {
      // Silently ignore — UI will refresh on next load
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final actor = item.actor;
    final hasPhoto = item.type == 'verification' &&
        (item.photoUrls?.isNotEmpty ?? false);

    return Semantics(
      label: '${_activityDescription()}, ${_timeAgo(item.createdAt)}',
      button: true,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/challenges/${item.challengeId}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    _ActorAvatar(actor: actor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            actor.nickname,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _timeAgo(item.createdAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  _activityDescription(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (hasPhoto) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.zero,
                  ),
                  child: Image.network(
                    item.photoUrls!.first,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
              _ClapRow(item: item, onClapTap: () => _onClapTap(ref)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActorAvatar extends StatelessWidget {
  const _ActorAvatar({required this.actor});

  final FeedActor actor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileUrl = actor.profileImageUrl;

    if (profileUrl != null && profileUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(profileUrl),
        onBackgroundImageError: (_, __) {},
        backgroundColor: theme.colorScheme.primaryContainer,
      );
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: Text(
        actor.nickname.isNotEmpty ? actor.nickname[0].toUpperCase() : '?',
        style: TextStyle(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ClapRow extends StatelessWidget {
  const _ClapRow({required this.item, required this.onClapTap});

  final FeedItemData item;
  final VoidCallback onClapTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: Row(
        children: [
          Semantics(
            label: item.hasClapped ? '박수 취소' : '박수 보내기',
            button: true,
            child: IconButton(
              icon: Icon(
                Icons.waving_hand,
                color: item.hasClapped
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              onPressed: onClapTap,
            ),
          ),
          Text(
            '${item.clapCount}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: item.hasClapped
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: item.hasClapped ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
