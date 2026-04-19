import 'package:flutter/material.dart';
import '../../../features/character/models/item_data.dart';
import '../models/room_equip.dart';
import '../models/room_slot.dart';

/// 슬롯별 아이템 그리드 — 소유/미소유/한정판 상태 표시.
class VariantGrid extends StatelessWidget {
  final MiniroomSlot slot;
  final List<UserItem> owned;
  final List<ShopItem> shop;

  /// 현재 이 슬롯에 선택된 아이템 ID (local edit state).
  final String? selectedItemId;

  /// 아이템 선택 시 콜백 — null 이면 아무 아이템도 선택하지 않은 상태.
  final ValueChanged<String?> onSelect;

  /// 미소유 아이템 구매 콜백. 반환 true 이면 구매 성공 → 자동 선택.
  final Future<bool> Function(ShopItem item)? onPurchase;

  const VariantGrid({
    super.key,
    required this.slot,
    required this.owned,
    required this.shop,
    required this.selectedItemId,
    required this.onSelect,
    this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    // 보유 아이템 ID 세트
    final ownedIds = owned.map((ui) => ui.item.id).toSet();

    // 보유 아이템을 앞에, 미보유 상점 아이템을 뒤에 배치
    final unownedShop =
        shop.where((s) => !ownedIds.contains(s.id)).toList();

    return GridView.count(
      crossAxisCount: 3,
      childAspectRatio: 0.8,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      children: [
        // 기본값 (null 선택)
        _DefaultCell(
          isSelected: selectedItemId == null,
          onTap: () => onSelect(null),
        ),
        // 소유 아이템
        for (final ui in owned)
          _OwnedCell(
            userItem: ui,
            isSelected: selectedItemId == ui.item.id,
            onTap: () => onSelect(ui.item.id),
          ),
        // 미소유 상점 아이템
        for (final shopItem in unownedShop)
          _ShopCell(
            shopItem: shopItem,
            onTap: onPurchase != null
                ? () => _handlePurchase(context, shopItem)
                : null,
          ),
      ],
    );
  }

  Future<void> _handlePurchase(BuildContext context, ShopItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _PurchaseConfirmDialog(item: item),
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await onPurchase!(item);
    if (ok && context.mounted) {
      onSelect(item.id);
    }
  }
}

// ─── 기본값 셀 ───

class _DefaultCell extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _DefaultCell({required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '기본값${isSelected ? ', 선택됨' : ''}',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: _ItemCellContainer(
          isSelected: isSelected,
          borderColor: theme.colorScheme.outline,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.restart_alt_rounded,
                size: 32,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              Text(
                '기본',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 소유 아이템 셀 ───

class _OwnedCell extends StatelessWidget {
  final UserItem userItem;
  final bool isSelected;
  final VoidCallback onTap;

  const _OwnedCell({
    required this.userItem,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = userItem.item;
    final rarityColor = _rarityColor(item.rarity);

    return Semantics(
      label:
          '${item.name}, ${_rarityLabel(item.rarity)}, 소유 중${isSelected ? ', 선택됨' : ''}',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: _ItemCellContainer(
          isSelected: isSelected,
          borderColor: rarityColor,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 아이템 미리보기 플레이스홀더 (procedural sprite)
              _ItemSprite(assetKey: item.assetKey, rarity: item.rarity),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  item.name,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _raritySymbol(item.rarity),
                    style: TextStyle(
                      fontSize: 8,
                      color: rarityColor,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    _rarityLabel(item.rarity),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: rarityColor,
                    ),
                  ),
                  if (item.isOwned == false && item is ShopItem) ...[
                    const SizedBox(width: 2),
                    const Text('✨', style: TextStyle(fontSize: 8)),
                  ],
                ],
              ),
              // 한정판 배지
              if (_isLimitedItem(item)) ...[
                const SizedBox(height: 2),
                const Text('✨', style: TextStyle(fontSize: 10)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _isLimitedItem(ShopItem item) => item.isOwned == false;
}

// ─── 미소유 상점 셀 ───

class _ShopCell extends StatelessWidget {
  final ShopItem shopItem;
  final VoidCallback? onTap;

  const _ShopCell({required this.shopItem, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label:
          '${shopItem.name}, ${_rarityLabel(shopItem.rarity)}, 미보유, 코인 ${shopItem.price}',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            _ItemCellContainer(
              isSelected: false,
              borderColor: theme.colorScheme.outlineVariant,
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.grey.withOpacity(0.4),
                  BlendMode.saturation,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ItemSprite(
                        assetKey: shopItem.assetKey,
                        rarity: shopItem.rarity),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        shopItem.name,
                        style: theme.textTheme.labelSmall,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '🪙 ${shopItem.price}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 잠금 아이콘
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 아이템 셀 컨테이너 ───

class _ItemCellContainer extends StatelessWidget {
  final bool isSelected;
  final Color borderColor;
  final Widget child;

  const _ItemCellContainer({
    required this.isSelected,
    required this.borderColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: isSelected
            ? borderColor.withOpacity(0.1)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? borderColor : theme.colorScheme.outlineVariant,
          width: isSelected ? 2.5 : 1.2,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: borderColor.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: child,
    );
  }
}

// ─── 아이템 sprite 플레이스홀더 ───

/// assetKey 기반의 procedural sprite 렌더.
/// Phase 2 에서는 assetKey → 색상/패턴 매핑으로 시각 구분.
class _ItemSprite extends StatelessWidget {
  final String assetKey;
  final String rarity;

  const _ItemSprite({required this.assetKey, required this.rarity});

  @override
  Widget build(BuildContext context) {
    final color = _assetKeyColor(assetKey);
    final size = 36.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Center(
        child: Icon(
          _assetKeyIcon(assetKey),
          size: 22,
          color: color,
        ),
      ),
    );
  }

  /// assetKey 접두어로 색상 결정.
  Color _assetKeyColor(String key) {
    if (key.startsWith('wall/')) return const Color(0xFFFFB3C1);
    if (key.startsWith('ceiling/')) return const Color(0xFFB3D9FF);
    if (key.startsWith('window/')) return const Color(0xFF90CAF9);
    if (key.startsWith('shelf/')) return const Color(0xFFD4A574);
    if (key.startsWith('plant/')) return const Color(0xFF81C784);
    if (key.startsWith('desk/')) return const Color(0xFFB07848);
    if (key.startsWith('rug/')) return const Color(0xFFF48FB1);
    if (key.startsWith('floor/')) return const Color(0xFFBCAAA4);
    return const Color(0xFFCE93D8);
  }

  /// assetKey 접두어로 아이콘 결정.
  IconData _assetKeyIcon(String key) {
    if (key.startsWith('wall/')) return Icons.wallpaper_rounded;
    if (key.startsWith('ceiling/')) return Icons.light_rounded;
    if (key.startsWith('window/')) return Icons.window_rounded;
    if (key.startsWith('shelf/')) return Icons.shelves;
    if (key.startsWith('plant/')) return Icons.local_florist_rounded;
    if (key.startsWith('desk/')) return Icons.desk_rounded;
    if (key.startsWith('rug/')) return Icons.rectangle_rounded;
    if (key.startsWith('floor/')) return Icons.grid_4x4_rounded;
    return Icons.star_rounded;
  }
}

// ─── 구매 확인 다이얼로그 ───

class _PurchaseConfirmDialog extends StatelessWidget {
  final ShopItem item;

  const _PurchaseConfirmDialog({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        item.name,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ItemSprite(assetKey: item.assetKey, rarity: item.rarity),
          const SizedBox(height: 12),
          Text(
            '🪙 ${item.price} 코인으로 구매하겠어요?',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('구매'),
        ),
      ],
    );
  }
}

// ─── 등급 헬퍼 ───

Color _rarityColor(String rarity) {
  switch (rarity) {
    case 'RARE':
      return const Color(0xFF1565C0);
    case 'EPIC':
      return const Color(0xFF6A1B9A);
    case 'LEGENDARY':
      return const Color(0xFFE65100);
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

/// 색각 보조용 기호.
String _raritySymbol(String rarity) {
  switch (rarity) {
    case 'COMMON':
      return '◇';
    case 'RARE':
      return '◆';
    case 'EPIC':
      return '★';
    default:
      return '✨';
  }
}
