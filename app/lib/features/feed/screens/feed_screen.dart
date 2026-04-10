import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/feed_provider.dart';
import '../widgets/feed_empty_view.dart';
import '../widgets/feed_item_card.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  Future<void> _refresh() async {
    ref.invalidate(feedListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(feedListProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: const Text('피드'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: feedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorView(onRetry: _refresh),
          data: (data) {
            if (data.items.isEmpty) {
              return const FeedEmptyView();
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: data.items.length,
              itemBuilder: (context, index) {
                return FeedItemCard(item: data.items[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Future<void> Function() onRetry;

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
                '피드를 불러오지 못했어요',
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
