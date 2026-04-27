import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../status_bar/providers/user_stats_provider.dart';
import '../models/gem_pack.dart';
import '../models/purchase_result.dart';
import '../providers/gem_packs_provider.dart';
import '../providers/treasure_chest_provider.dart';
import '../widgets/gem_pack_card.dart';
import '../widgets/treasure_chest_card.dart';

class GemsScreen extends ConsumerWidget {
  const GemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chest = ref.watch(treasureChestProvider);
    final packs = ref.watch(gemPacksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('보석')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            chest.when(
              loading: () => const SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('보물상자 불러오기 실패: $e'),
              ),
              data: (c) => TreasureChestCard(
                chest: c,
                onOpen: () => _handleOpen(context, ref),
              ),
            ),
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '보석 충전',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            packs.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('충전 옵션 불러오기 실패: $e'),
              ),
              data: (list) => Column(
                children: list
                    .map((p) => GemPackCard(
                          pack: p,
                          onPurchase: () => _handlePurchase(context, ref, p),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _handleOpen(BuildContext context, WidgetRef ref) async {
    final dio = ref.read(dioProvider);
    try {
      final response = await dio.post('/gems/chest/open');
      ref.invalidate(treasureChestProvider);
      ref.invalidate(userStatsProvider);
      if (context.mounted) {
        final reward = (response.data as Map)['reward_gems'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$reward보석 획득!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('열기 실패: $e')),
        );
      }
    }
  }

  Future<void> _handlePurchase(
      BuildContext context, WidgetRef ref, GemPack p) async {
    final dio = ref.read(dioProvider);
    try {
      final response = await dio.post('/gems/packs/${p.id}/purchase');
      final result =
          PurchaseResult.fromJson(response.data as Map<String, dynamic>);
      ref.invalidate(userStatsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${result.awardedGems}보석 충전 완료 (잔액 ${result.balance})')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('구매 실패: $e')),
        );
      }
    }
  }
}
