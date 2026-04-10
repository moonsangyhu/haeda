import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/character_avatar.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/item_data.dart';
import '../providers/shop_provider.dart';

/// 상점 화면 — bottom tab (index 2).
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = ['모자', '상의', '하의', '신발', '액세서리'];
  static const _categoryKeys = ['HAT', 'TOP', 'BOTTOM', 'SHOES', 'ACCESSORY'];

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _onPurchase(BuildContext context, ShopItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('구매 확인'),
        content: Text('${item.name}을(를) 구매할까요?\n(${item.price}코인)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('구매'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final notifier = ref.read(shopPurchaseProvider.notifier);
    final success = await notifier.purchaseItem(item.id);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('구매 완료!')),
      );
      // Refresh all shop item categories
      for (final cat in _categoryKeys) {
        ref.invalidate(shopItemsProvider(cat));
      }
    } else {
      final state = ref.read(shopPurchaseProvider);
      _handlePurchaseError(context, state.errorCode);
    }
  }

  void _handlePurchaseError(BuildContext context, String? code) {
    switch (code) {
      case 'INSUFFICIENT_COINS':
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('코인 부족'),
            content: const Text('코인이 부족해요!\n챌린지를 더 열심히 해볼까요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      case 'ALREADY_OWNED':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 보유한 아이템이에요')),
        );
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('구매에 실패했어요.')),
        );
    }
  }

  void _showItemDetail(BuildContext context, ShopItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ItemDetailSheet(
        item: item,
        onPurchase: () {
          Navigator.of(ctx).pop();
          _onPurchase(context, item);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryKey = _categoryKeys[_tabController.index];
    final itemsAsync = ref.watch(shopItemsProvider(categoryKey));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('상점'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs.map((t) => Tab(text: t, height: 36)).toList(),
        ),
      ),
      body: itemsAsync.when(
        loading: () => const LoadingWidget(),
        error: (_, __) => const Center(child: Text('아이템을 불러올 수 없어요.')),
        data: (items) => _ShopGrid(
          items: items,
          onPurchase: (item) => _onPurchase(context, item),
          onTap: (item) => _showItemDetail(context, item),
        ),
      ),
    );
  }
}

class _ShopGrid extends StatelessWidget {
  final List<ShopItem> items;
  final void Function(ShopItem) onPurchase;
  final void Function(ShopItem) onTap;

  const _ShopGrid({
    required this.items,
    required this.onPurchase,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('아이템이 없어요.'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) => GestureDetector(
        onTap: () => onTap(items[i]),
        child: _ShopItemCard(
          item: items[i],
          onPurchase: () => onPurchase(items[i]),
        ),
      ),
    );
  }
}

class _ShopItemCard extends StatelessWidget {
  final ShopItem item;
  final VoidCallback onPurchase;

  const _ShopItemCard({required this.item, required this.onPurchase});

  Color _rarityColor() {
    switch (item.rarity) {
      case 'RARE':
        return const Color(0xFF2196F3);
      case 'EPIC':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rarityColor = _rarityColor();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item pixel art preview
            Expanded(
              child: Center(
                child: ItemPreview(
                  assetKey: item.assetKey,
                  rarity: item.rarity,
                  size: 72,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Rarity badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: rarityColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.rarity,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: rarityColor,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.name,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (item.effectType != null) ...[
              const SizedBox(height: 4),
              Text(
                _effectDescription(item.effectType!, item.effectValue ?? 0),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            // Price / owned
            if (item.isOwned)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '보유',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              FilledButton(
                onPressed: onPurchase,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 34),
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(fontSize: 13),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('💎', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text('${item.price}'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemDetailSheet extends StatelessWidget {
  final ShopItem item;
  final VoidCallback onPurchase;

  const _ItemDetailSheet({required this.item, required this.onPurchase});

  Color _rarityColor() {
    switch (item.rarity) {
      case 'RARE':
        return const Color(0xFF2196F3);
      case 'EPIC':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rarityColor = _rarityColor();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Large item preview
            Center(
              child: ItemPreview(
                assetKey: item.assetKey,
                rarity: item.rarity,
                size: 160,
              ),
            ),
            const SizedBox(height: 20),
            // Item name
            Text(
              item.name,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Rarity badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: rarityColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item.rarity,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: rarityColor,
                ),
              ),
            ),
            // Effect description
            if (item.effectType != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _effectDescription(
                          item.effectType!, item.effectValue ?? 0),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.tertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Purchase button or owned indicator
            if (item.isOwned)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '보유 중인 아이템',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              FilledButton(
                onPressed: onPurchase,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('💎', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text('${item.price} 보석으로 구매'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _effectDescription(String type, int value) {
  switch (type) {
    case 'STREAK_SHIELD':
      return '연속 깨짐 ${value}회 방지';
    case 'COIN_BOOST':
      return '코인 획득 +$value%';
    case 'VERIFY_BONUS':
      return '인증 시 +$value 코인';
    default:
      return '';
  }
}
