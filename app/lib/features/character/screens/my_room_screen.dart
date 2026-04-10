import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/character_avatar.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/character_data.dart';
import '../models/item_data.dart';
import '../providers/character_provider.dart';
import '../providers/coin_provider.dart';

/// 내 방 탭 - 캐릭터 꾸미기 메인 화면.
class MyRoomScreen extends ConsumerStatefulWidget {
  const MyRoomScreen({super.key});

  @override
  ConsumerState<MyRoomScreen> createState() => _MyRoomScreenState();
}

class _MyRoomScreenState extends ConsumerState<MyRoomScreen>
    with SingleTickerProviderStateMixin {
  static const _categories = ['모자', '상의', '하의', '신발', '액세서리'];
  static const _categoryKeys = ['hat', 'top', 'bottom', 'shoes', 'accessory'];

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showTransactionSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _CoinTransactionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final characterAsync = ref.watch(myCharacterProvider);
    final balanceAsync = ref.watch(coinBalanceProvider);
    final itemsAsync = ref.watch(myItemsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top: coin balance + 상점 button
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _showTransactionSheet,
                    child: balanceAsync.when(
                      loading: () => const SizedBox(
                        width: 60,
                        height: 20,
                        child: LinearProgressIndicator(),
                      ),
                      error: (_, __) => const Text('- 코인'),
                      data: (b) => Text(
                        '${b.balance} 코인',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.go('/shop'),
                    child: const Text('상점'),
                  ),
                ],
              ),
            ),

            // Character area
            characterAsync.when(
              loading: () => const SizedBox(
                height: 220,
                child: Center(child: LoadingWidget()),
              ),
              error: (_, __) => const SizedBox(
                height: 220,
                child: Center(child: Text('캐릭터를 불러올 수 없어요.')),
              ),
              data: (character) => _CharacterSection(character: character),
            ),

            const SizedBox(height: 8),

            // Category tabs
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: _categories
                  .map((c) => Tab(text: c, height: 36))
                  .toList(),
            ),

            // Item grid
            Expanded(
              child: itemsAsync.when(
                loading: () => const LoadingWidget(),
                error: (_, __) =>
                    const Center(child: Text('아이템을 불러올 수 없어요.')),
                data: (items) {
                  final category = _categoryKeys[_tabController.index];
                  final filtered = items
                      .where((ui) => ui.item.category == category)
                      .toList();
                  return characterAsync.maybeWhen(
                    data: (character) => _ItemGrid(
                      items: filtered,
                      character: character,
                      category: category,
                    ),
                    orElse: () => _ItemGrid(
                      items: filtered,
                      character: null,
                      category: category,
                    ),
                  );
                },
              ),
            ),

            // Bottom link - navigate to shop tab
            GestureDetector(
              onTap: () => context.go('/shop'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '상점에서 더 구경하기 →',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CharacterSection extends StatelessWidget {
  final CharacterData character;
  const _CharacterSection({required this.character});

  bool get _hasEpic {
    return [
      character.hat,
      character.top,
      character.bottom,
      character.shoes,
      character.accessory,
    ].any((s) => s?.rarity == 'EPIC');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CharacterAvatar(
              character: character,
              size: 180,
              showEffect: _hasEpic,
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemGrid extends ConsumerWidget {
  final List<UserItem> items;
  final CharacterData? character;
  final String category;

  const _ItemGrid({
    required this.items,
    required this.character,
    required this.category,
  });

  bool _isEquipped(UserItem ui) {
    if (character == null) return false;
    final slot = _equippedSlot();
    return slot?.id == ui.item.id;
  }

  CharacterSlot? _equippedSlot() {
    if (character == null) return null;
    switch (category) {
      case 'hat':
        return character!.hat;
      case 'top':
        return character!.top;
      case 'bottom':
        return character!.bottom;
      case 'shoes':
        return character!.shoes;
      case 'accessory':
        return character!.accessory;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🛍️', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(
              '보유한 아이템이 없어요.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final ui = items[i];
        final equipped = _isEquipped(ui);
        return _ItemCard(
          userItem: ui,
          isEquipped: equipped,
          onTap: () => _onTap(ctx, ref, ui, equipped),
        );
      },
    );
  }

  Future<void> _onTap(
    BuildContext context,
    WidgetRef ref,
    UserItem ui,
    bool equipped,
  ) async {
    final notifier = ref.read(characterUpdateProvider.notifier);
    // Equip or unequip
    final newItemId = equipped ? null : ui.item.id;
    final success = await notifier.updateSlot(category, newItemId);
    if (!context.mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이템 변경에 실패했어요.')),
      );
    }
  }
}

class _ItemCard extends StatelessWidget {
  final UserItem userItem;
  final bool isEquipped;
  final VoidCallback onTap;

  const _ItemCard({
    required this.userItem,
    required this.isEquipped,
    required this.onTap,
  });

  Color _rarityColor() {
    switch (userItem.item.rarity) {
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

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isEquipped
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isEquipped
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: isEquipped ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isEquipped
                  ? theme.colorScheme.primary.withOpacity(0.2)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Item placeholder icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: rarityColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _categoryEmoji(userItem.item.category),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                userItem.item.name,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight:
                      isEquipped ? FontWeight.w700 : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: rarityColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                userItem.item.rarity,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: rarityColor,
                ),
              ),
            ),
            if (userItem.item.effectType != null) ...[
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  _effectShortLabel(userItem.item.effectType!),
                  style: TextStyle(
                    fontSize: 8,
                    color: theme.colorScheme.tertiary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (isEquipped) ...[
              const SizedBox(height: 4),
              Text(
                '착용 중',
                style: TextStyle(
                  fontSize: 9,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _categoryEmoji(String category) {
  switch (category) {
    case 'hat':
      return '🎩';
    case 'top':
      return '👕';
    case 'bottom':
      return '👖';
    case 'shoes':
      return '👟';
    case 'accessory':
      return '✨';
    default:
      return '🎁';
  }
}

String _effectShortLabel(String effectType) {
  switch (effectType) {
    case 'STREAK_SHIELD':
      return '🛡️ 실드';
    case 'COIN_BOOST':
      return '💰 부스트';
    case 'VERIFY_BONUS':
      return '⭐ 보너스';
    default:
      return '';
  }
}

/// 코인 거래 내역 바텀시트.
class _CoinTransactionSheet extends ConsumerWidget {
  const _CoinTransactionSheet();

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final txAsync = ref.watch(coinTransactionsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              '코인 내역',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: txAsync.when(
              loading: () => const LoadingWidget(),
              error: (_, __) =>
                  const Center(child: Text('내역을 불러올 수 없어요.')),
              data: (txList) {
                if (txList.items.isEmpty) {
                  return const Center(child: Text('거래 내역이 없어요.'));
                }
                return ListView.separated(
                  controller: scrollController,
                  itemCount: txList.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final tx = txList.items[i];
                    final isGain = tx.amount > 0;
                    return ListTile(
                      dense: true,
                      leading: Text(
                        isGain ? '🪙' : '💸',
                        style: const TextStyle(fontSize: 20),
                      ),
                      title: Text(tx.type),
                      subtitle: Text(_formatDate(tx.createdAt)),
                      trailing: Text(
                        '${isGain ? '+' : ''}${tx.amount}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isGain
                              ? const Color(0xFF2E7D32)
                              : theme.colorScheme.error,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

