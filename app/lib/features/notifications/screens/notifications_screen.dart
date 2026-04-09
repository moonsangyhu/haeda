import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../models/notification_data.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  int _offset = 0;

  Future<void> _refresh() async {
    setState(() => _offset = 0);
    ref.invalidate(notificationListProvider);
    ref.invalidate(unreadCountProvider);
  }

  Future<void> _markRead(String notificationId) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/notifications/$notificationId/read');
      ref.invalidate(notificationListProvider);
      ref.invalidate(unreadCountProvider);
    } on DioException {
      // Silently ignore — UI state will refresh on next load
    }
  }

  void _onTap(BuildContext context, NotificationItem item) {
    if (!item.isRead) {
      _markRead(item.id);
    }
    final challengeId = item.dataJson?['challenge_id'] as String?;
    if (challengeId != null) {
      context.push('/challenges/$challengeId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(notificationListProvider(_offset));

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: listAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorView(onRetry: _refresh),
          data: (data) {
            if (data.notifications.isEmpty) {
              return const _EmptyView();
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: data.notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final item = data.notifications[index];
                return _NotificationTile(
                  item: item,
                  onTap: () => _onTap(context, item),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotificationTile({required this.item, required this.onTap});

  IconData _iconForType(String type) {
    switch (type) {
      case 'nudge':
        return Icons.touch_app_outlined;
      case 'verification':
        return Icons.check_circle_outline;
      case 'comment':
        return Icons.chat_bubble_outline;
      case 'challenge_complete':
        return Icons.emoji_events_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = !item.isRead;

    return Semantics(
      label: '${item.title}: ${item.body}, ${_timeAgo(item.createdAt)}${isUnread ? ', 읽지 않음' : ''}',
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: isUnread
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isUnread
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconForType(item.type),
                  size: 20,
                  color: isUnread
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _timeAgo(item.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        Center(
          child: Column(
            children: [
              Icon(
                Icons.notifications_off_outlined,
                size: 48,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                '아직 알림이 없어요',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        Center(
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                '알림을 불러오지 못했어요',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: onRetry,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
