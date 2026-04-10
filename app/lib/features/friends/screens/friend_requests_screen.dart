import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../models/friend_data.dart';
import '../providers/friend_provider.dart';
import '../widgets/friend_tile.dart';

class FriendRequestsScreen extends ConsumerWidget {
  const FriendRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('받은 요청'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(pendingRequestsProvider.future),
        child: requestsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text('불러오기 실패: $error'),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => ref.invalidate(pendingRequestsProvider),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
          data: (data) {
            if (data.requests.isEmpty) {
              return const _EmptyRequestsView();
            }
            return ListView.builder(
              itemCount: data.requests.length,
              itemBuilder: (context, index) {
                final request = data.requests[index];
                return _RequestTile(request: request);
              },
            );
          },
        ),
      ),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  const _RequestTile({required this.request});

  final FriendRequestItem request;

  String _timeAgo(String createdAt) {
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  Future<void> _handleAccept(BuildContext context, WidgetRef ref) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/friends/requests/${request.id}/accept');
      ref.invalidate(pendingRequestsProvider);
      ref.invalidate(friendsListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('친구가 되었어요!')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오류가 발생했어요. 다시 시도해 주세요.')),
        );
      }
    }
  }

  Future<void> _handleReject(BuildContext context, WidgetRef ref) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/friends/requests/${request.id}/reject');
      ref.invalidate(pendingRequestsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오류가 발생했어요. 다시 시도해 주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return FriendTile(
      nickname: request.user.nickname,
      profileImageUrl: request.user.profileImageUrl,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _timeAgo(request.createdAt),
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => _handleAccept(context, ref),
            style: FilledButton.styleFrom(
              minimumSize: const Size(56, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('수락'),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: () => _handleReject(context, ref),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(56, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('거절'),
          ),
        ],
      ),
    );
  }
}

class _EmptyRequestsView extends StatelessWidget {
  const _EmptyRequestsView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mail_outline,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
            ),
            const SizedBox(height: 16),
            Text(
              '받은 요청이 없어요',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
