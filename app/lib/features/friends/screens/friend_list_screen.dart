import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/friend_provider.dart';
import '../widgets/friend_tile.dart';

class FriendListScreen extends ConsumerWidget {
  const FriendListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('친구 목록'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(friendsListProvider.future),
        child: friendsAsync.when(
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
                  onPressed: () => ref.invalidate(friendsListProvider),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
          data: (data) {
            if (data.friends.isEmpty) {
              return _EmptyFriendsView(
                onFindFriends: () => context.push('/friends/contact-search'),
              );
            }
            return ListView.builder(
              itemCount: data.friends.length,
              itemBuilder: (context, index) {
                final friend = data.friends[index];
                return FriendTile(
                  nickname: friend.nickname,
                  profileImageUrl: friend.profileImageUrl,
                  trailing: IconButton(
                    icon: const Icon(Icons.person_remove_outlined),
                    tooltip: '친구 삭제',
                    onPressed: () =>
                        _confirmDelete(context, ref, friend.nickname),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String nickname,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('친구 삭제'),
        content: Text('$nickname 님을 친구 목록에서 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              '삭제',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('준비 중입니다')),
      );
    }
  }
}

class _EmptyFriendsView extends StatelessWidget {
  const _EmptyFriendsView({required this.onFindFriends});

  final VoidCallback onFindFriends;

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
              Icons.people_outline,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
            ),
            const SizedBox(height: 16),
            Text(
              '아직 친구가 없어요',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onFindFriends,
              icon: const Icon(Icons.person_search),
              label: const Text('친구 찾기'),
            ),
          ],
        ),
      ),
    );
  }
}
