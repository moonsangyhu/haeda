import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/item_icon_painter.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/miniroom_scene.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/character_data.dart';
import '../models/item_data.dart';
import '../providers/character_provider.dart';
import '../providers/coin_provider.dart';
import '../widgets/equip_stat_bar.dart';

/// 내 방 탭 — 캐릭터 + 카테고리별 아이템 그리드 + 탭→바텀시트.
class MyRoomScreen extends ConsumerStatefulWidget {
  const MyRoomScreen({super.key});

  @override
  ConsumerState<MyRoomScreen> createState() => _MyRoomScreenState();
}

class _MyRoomScreenState extends ConsumerState<MyRoomScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = ['모자', '상의', '하의', '신발', '액세서리'];
  static const _keys = ['HAT', 'TOP', 'BOTTOM', 'SHOES', 'ACCESSORY'];

  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final character = ref.watch(myCharacterProvider).valueOrNull;
    final allItems = ref.watch(myItemsProvider).valueOrNull ?? [];

    final catKey = _keys[_tabCtrl.index];
    final filtered =
        allItems.where((ui) => ui.item.category.toUpperCase() == catKey).toList();

    // 착용 중인 아이템들의 효과 합산
    final equippedItems = getEquippedItems(allItems, character);
    final stats = calcEquipStats(equippedItems);

    // Wall tint from user background color
    final bgHex =
        ref.watch(authStateProvider).valueOrNull?.backgroundColor;
    final userBgColor = AppTheme.characterBackgroundFromHex(bgHex);

    // Responsive sizing
    final screenHeight = MediaQuery.of(context).size.height;
    final roomHeight = screenHeight < 600 ? 200.0 : 250.0;
    final charSize = screenHeight < 600 ? 90.0 : 110.0;

    return Scaffold(
      floatingActionButton: Semantics(
        label: '미니룸 꾸미기 편집',
        child: FloatingActionButton(
          onPressed: () => context.push('/room-decorator'),
          tooltip: '내 방 꾸미기',
          child: const Icon(Icons.edit_rounded),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // ── 미니룸 씬
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(13),
                  topRight: Radius.circular(13),
                ),
                child: MiniroomScene(
                  character: character,
                  wallTintColor: userBgColor,
                  height: roomHeight,
                  characterSize: charSize,
                ),
              ),
            ),

            // ── 능력치 바
            EquipStatBar(stats: stats),

            const SizedBox(height: 4),

            // ── 카테고리 탭
            TabBar(
              controller: _tabCtrl,
              isScrollable: false,
              labelPadding: EdgeInsets.zero,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color(0xFFFFCDD2),
              ),
              tabs: _tabs.map((t) => Tab(text: t, height: 36)).toList(),
            ),

            // ── 아이템 그리드
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        '보유한 아이템이 없어요',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(14),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.78,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final ui = filtered[i];
                        final equipped = _isEquipped(ui, character);
                        return _ItemCard(
                          userItem: ui,
                          isEquipped: equipped,
                          onTap: () => _showItemSheet(ui, equipped),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isEquipped(UserItem ui, CharacterData? c) {
    if (c == null) return false;
    switch (ui.item.category.toUpperCase()) {
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

  void _showItemSheet(UserItem ui, bool equipped) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ItemDetailSheet(
        userItem: ui,
        isEquipped: equipped,
        onEquipToggle: () async {
          Navigator.pop(ctx);
          final slot = ui.item.category.toLowerCase();
          final newId = equipped ? null : ui.item.id;
          final ok = await ref
              .read(myCharacterProvider.notifier)
              .updateSlot(slot, newId);
          if (!mounted) return;
          if (!ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('아이템 변경에 실패했어요.')),
            );
          }
        },
      ),
    );
  }
}

// ─── (stat logic moved to ../widgets/miniroom_stat_overlay.dart) ───

// ─── 등급별 테두리 색상 ───

Color _rarityBorder(String rarity) {
  switch (rarity) {
    case 'RARE':
      return const Color(0xFFFFD600); // 노란색
    case 'EPIC':
      return const Color(0xFF9C27B0); // 보라색
    case 'LEGENDARY':
      return const Color(0xFFFFAB00); // 황금색
    default:
      return const Color(0xFFBDBDBD); // 회색
  }
}

Color _rarityTextColor(String rarity) {
  switch (rarity) {
    case 'RARE':
      return const Color(0xFFE6A800);
    case 'EPIC':
      return const Color(0xFF7B1FA2);
    case 'LEGENDARY':
      return const Color(0xFFFF8F00);
    default:
      return const Color(0xFF757575);
  }
}

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

String _categoryLabel(String cat) {
  switch (cat.toUpperCase()) {
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
      return cat;
  }
}

String _effectText(String type, int value) {
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

// ─── 아이템 카드 (그리드) ───

class _ItemCard extends StatelessWidget {
  final UserItem userItem;
  final bool isEquipped;
  final VoidCallback onTap;

  const _ItemCard({
    required this.userItem,
    required this.isEquipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = userItem.item;
    final border = _rarityBorder(item.rarity);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: isEquipped
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [border.withOpacity(0.12), border.withOpacity(0.04)],
                )
              : null,
          color: isEquipped ? null : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: border,
            width: isEquipped ? 2.5 : 1.5,
          ),
          boxShadow: isEquipped
              ? [BoxShadow(color: border.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 도트 아이템 미리보기
            ItemPreview(
              assetKey: item.assetKey,
              rarity: item.rarity,
              size: 52,
            ),
            const SizedBox(height: 6),
            // 이름
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                item.name,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: isEquipped ? FontWeight.w700 : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            // 등급 뱃지
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: border.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: border, width: 0.5),
              ),
              child: Text(
                _rarityLabel(item.rarity),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _rarityTextColor(item.rarity),
                ),
              ),
            ),
            // 착용 중
            if (isEquipped) ...[
              const SizedBox(height: 4),
              Text(
                '착용 중',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: _rarityTextColor(item.rarity),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── 아이템 상세 바텀시트 ───

class _ItemDetailSheet extends StatelessWidget {
  final UserItem userItem;
  final bool isEquipped;
  final VoidCallback onEquipToggle;

  const _ItemDetailSheet({
    required this.userItem,
    required this.isEquipped,
    required this.onEquipToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = userItem.item;
    final border = _rarityBorder(item.rarity);
    final hasEffect = item.effectType != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // 아이템 이름
          Text(
            item.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),

          // 큰 도트 미리보기
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: border.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border, width: 2),
            ),
            child: ItemPreview(
              assetKey: item.assetKey,
              rarity: item.rarity,
              size: 120,
            ),
          ),
          const SizedBox(height: 16),

          // 등급 + 카테고리
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: border.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: border, width: 1),
                ),
                child: Text(
                  _rarityLabel(item.rarity),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _rarityTextColor(item.rarity),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _categoryLabel(item.category),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '🪙 ${item.price}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 효과
          if (hasEffect)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _effectText(item.effectType!, item.effectValue ?? 0),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.tertiary,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            Text(
              '장식용 아이템',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

          const SizedBox(height: 20),

          // 착용/해제 버튼
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onEquipToggle,
              style: ElevatedButton.styleFrom(
                backgroundColor: isEquipped
                    ? theme.colorScheme.surfaceContainerHighest
                    : border,
                foregroundColor: isEquipped
                    ? theme.colorScheme.onSurface
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: isEquipped ? 0 : 2,
              ),
              child: Text(
                isEquipped ? '해제하기' : '착용하기',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 닫기
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '닫기',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// 코인 거래 내역 바텀시트.
class _CoinTransactionSheet extends ConsumerWidget {
  const _CoinTransactionSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final txAsync = ref.watch(coinTransactionsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
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
                  controller: scrollCtrl,
                  itemCount: txList.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final tx = txList.items[i];
                    final gain = tx.amount > 0;
                    return ListTile(
                      dense: true,
                      leading: Text(gain ? '🪙' : '💸',
                          style: const TextStyle(fontSize: 20)),
                      title: Text(tx.type),
                      trailing: Text(
                        '${gain ? '+' : ''}${tx.amount}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: gain
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

