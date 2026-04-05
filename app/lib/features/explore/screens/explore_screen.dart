import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart';
import '../providers/explore_provider.dart';
import '../widgets/public_challenge_card.dart';

const _categories = [
  (label: '전체', value: null),
  (label: '운동', value: '운동'),
  (label: '공부', value: '공부'),
  (label: '생활', value: '생활'),
  (label: '식단', value: '식단'),
  (label: '기타', value: '기타'),
];

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  @override
  void initState() {
    super.initState();
    // 탭 진입 시마다 최신 공개 챌린지 목록을 fetch
    Future.microtask(() => ref.invalidate(publicChallengesProvider));
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final challengesAsync = ref.watch(publicChallengesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('탐색'),
      ),
      body: Column(
        children: [
          // Category filter chips
          SizedBox(
            height: 56,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = selectedCategory == cat.value;

                return FilterChip(
                  label: Text(cat.label),
                  selected: isSelected,
                  onSelected: (_) {
                    ref
                        .read(selectedCategoryProvider.notifier)
                        .state = cat.value;
                  },
                  showCheckmark: false,
                );
              },
            ),
          ),
          // Challenge list
          Expanded(
            child: challengesAsync.when(
              loading: () => const LoadingWidget(),
              error: (error, _) => AppErrorWidget(
                error: error,
                onRetry: () =>
                    ref.invalidate(publicChallengesProvider),
              ),
              data: (challenges) {
                if (challenges.isEmpty) {
                  return const Center(
                    child: Text('공개 챌린지가 없습니다'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(publicChallengesProvider);
                    await ref.read(publicChallengesProvider.future);
                  },
                  child: ListView.builder(
                    itemCount: challenges.length,
                    itemBuilder: (context, index) {
                      final challenge = challenges[index];
                      return PublicChallengeCard(
                        challenge: challenge,
                        onTap: () =>
                            context.push('/challenges/${challenge.id}'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
