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

class _MyRoomScreenState extends ConsumerState<MyRoomScreen> {
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
    final character = characterAsync.valueOrNull;
    final items = itemsAsync.valueOrNull ?? [];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top: coin balance
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
                    child: const Text('상점 →'),
                  ),
                ],
              ),
            ),

            // Character area
            _CharacterSection(character: character),

            const SizedBox(height: 12),

            // Section header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    '보유 아이템',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${items.length}개',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // All items list (no category tabs)
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🛍️', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 8),
                          Text(
                            '보유한 아이템이 없어요.\n상점에서 아이템을 구매해보세요!',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : _AllItemsList(
                      items: items,
                      character: character,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CharacterSection extends StatelessWidget {
  final CharacterData? character;
  const _CharacterSection({required this.character});

  bool get _hasEpic {
    final c = character;
    if (c == null) return false;
    return [c.hat, c.top, c.bottom, c.shoes, c.accessory]
        .any((s) => s?.rarity == 'EPIC');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Center(
        child: CharacterAvatar(
          character: character,
          size: 180,
          showEffect: _hasEpic,
        ),
      ),
    );
  }
}

/// 전체 보유 아이템을 리스트로 표시. 등급별 테두리 색상 + 착용 중 뱃지.
class _AllItemsList extends ConsumerWidget {
  final List<UserItem> items;
  final CharacterData? character;

  const _AllItemsList({
    required this.items,
    required this.character,
  });

  bool _isEquipped(UserItem ui) {
    final c = character;
    if (c == null) return false;
    final cat = ui.item.category.toUpperCase();
    switch (cat) {
      case 'HAT':
        return c.hat?.id == ui.item.id;
      case 'TOP':
        return c.top?.id == ui.item.id;
      case 'BOTTOM':
        return c.bottom?.id == ui.item.id;
      case 'SHOES':
        return c.shoes?.id == ui.item.id;
      case 'ACCESSORY':
        return c.accessory?.id == ui.item.id;
      default:
        return false;
    }
  }

  String _slotKey(UserItem ui) {
    switch (ui.item.category.toUpperCase()) {
      case 'HAT':
        return 'hat';
      case 'TOP':
        return 'top';
      case 'BOTTOM':
        return 'bottom';
      case 'SHOES':
        return 'shoes';
      case 'ACCESSORY':
        return 'accessory';
      default:
        return 'hat';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final ui = items[i];
        final equipped = _isEquipped(ui);
        return _ItemTile(
          userItem: ui,
          isEquipped: equipped,
          onTap: () async {
            final notifier = ref.read(characterUpdateProvider.notifier);
            final slot = _slotKey(ui);
            final newId = equipped ? null : ui.item.id;
            final ok = await notifier.updateSlot(slot, newId);
            if (!ctx.mounted) return;
            if (!ok) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('아이템 변경에 실패했어요.')),
              );
            }
          },
        );
      },
    );
  }
}

/// 등급별 테두리 색상.
/// COMMON=회색, RARE=노란색, EPIC=보라색, LEGENDARY=황금색.
Color _rarityBorderColor(String rarity) {
  switch (rarity) {
    case 'RARE':
      return const Color(0xFFFFD600); // 노란색
    case 'EPIC':
      return const Color(0xFF9C27B0); // 보라색
    case 'LEGENDARY':
      return const Color(0xFFFFAB00); // 황금색
    default: // COMMON
      return const Color(0xFFBDBDBD); // 회색
  }
}

/// 등급 라벨 텍스트.
String _rarityLabel(String rarity) {
  switch (rarity) {
    case 'COMMON':
      return '노말';
    case 'RARE':
      return '레어';
    case 'EPIC':
      return '에픽';
    case 'LEGENDARY':
      return '전설';
    default:
      return rarity;
  }
}

String _categoryLabel(String category) {
  switch (category.toUpperCase()) {
    case 'HAT':
      return '모자';
    case 'TOP':
      return '상의';
    case 'BOTTOM':
      return '하의';
    case 'SHOES':
      return '신발';
    case 'ACCESSORY':
      return '액세서리';
    default:
      return category;
  }
}

String _categoryEmoji(String category) {
  switch (category.toUpperCase()) {
    case 'HAT':
      return '🎩';
    case 'TOP':
      return '👕';
    case 'BOTTOM':
      return '👖';
    case 'SHOES':
      return '👟';
    case 'ACCESSORY':
      return '✨';
    default:
      return '🎁';
  }
}

String _effectDescription(String type, int value) {
  switch (type) {
    case 'STREAK_SHIELD':
      return '🛡️ 연속 깨짐 $value회 방지';
    case 'COIN_BOOST':
      return '💰 코인 획득 +$value%';
    case 'VERIFY_BONUS':
      return '⭐ 인증 시 +$value 코인';
    default:
      return '';
  }
}

/// 아이템 리스트 타일 — 등급별 테두리 + 착용 중 뱃지.
class _ItemTile extends StatelessWidget {
  final UserItem userItem;
  final bool isEquipped;
  final VoidCallback onTap;

  const _ItemTile({
    required this.userItem,
    required this.isEquipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = userItem.item;
    final borderColor = _rarityBorderColor(item.rarity);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isEquipped
              ? borderColor.withOpacity(0.08)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isEquipped ? 2.5 : 1.5,
          ),
          boxShadow: [
            if (isEquipped)
              BoxShadow(
                color: borderColor.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            // Icon area
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: borderColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: borderColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  _categoryEmoji(item.category),
                  style: const TextStyle(fontSize: 26),
                ),
              ),
            ),

            const SizedBox(width: 14),

            // Item info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + rarity badge row
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: borderColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: borderColor,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _rarityLabel(item.rarity),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: borderColor == const Color(0xFFBDBDBD)
                                ? const Color(0xFF757575)
                                : borderColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Category + effect
                  Row(
                    children: [
                      Text(
                        _categoryLabel(item.category),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (item.effectType != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _effectDescription(
                              item.effectType!,
                              item.effectValue ?? 0,
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.tertiary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Equipped badge
            if (isEquipped)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: borderColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Text(
                  '착용 중',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: borderColor == const Color(0xFFBDBDBD)
                        ? const Color(0xFF616161)
                        : borderColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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

