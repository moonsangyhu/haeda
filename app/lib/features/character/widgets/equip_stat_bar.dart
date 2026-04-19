import 'package:flutter/material.dart';
import '../models/character_data.dart';
import '../models/item_data.dart';

/// Equipment stat totals.
class EquipStats {
  final int coinBoost;
  final int verifyBonus;
  final int streakShield;

  const EquipStats({
    this.coinBoost = 0,
    this.verifyBonus = 0,
    this.streakShield = 0,
  });

  bool get isEmpty => coinBoost == 0 && verifyBonus == 0 && streakShield == 0;
}

/// Extract equipped items from all owned items.
List<ShopItem> getEquippedItems(List<UserItem> allItems, CharacterData? c) {
  if (c == null) return [];
  final equippedIds = <String?>[
    c.hat?.id, c.top?.id, c.bottom?.id, c.shoes?.id, c.accessory?.id,
  ].whereType<String>().toSet();
  return allItems
      .where((ui) => equippedIds.contains(ui.item.id))
      .map((ui) => ui.item)
      .toList();
}

/// Sum effect values from equipped items.
EquipStats calcEquipStats(List<ShopItem> items) {
  int coin = 0, verify = 0, shield = 0;
  for (final item in items) {
    if (item.effectType == null) continue;
    final v = item.effectValue ?? 0;
    switch (item.effectType) {
      case 'COIN_BOOST':
        coin += v;
      case 'VERIFY_BONUS':
        verify += v;
      case 'STREAK_SHIELD':
        shield += v;
    }
  }
  return EquipStats(coinBoost: coin, verifyBonus: verify, streakShield: shield);
}

/// Horizontal stat bar displayed below the miniroom scene.
class EquipStatBar extends StatelessWidget {
  final EquipStats stats;
  const EquipStatBar({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: stats.isEmpty
          ? Center(
              child: Text(
                '효과 아이템을 착용해보세요!',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(
                  icon: '💰',
                  label: '코인부스트',
                  value: '+${stats.coinBoost}%',
                  active: stats.coinBoost > 0,
                ),
                _StatChip(
                  icon: '⭐',
                  label: '인증보너스',
                  value: '+${stats.verifyBonus}',
                  active: stats.verifyBonus > 0,
                ),
                _StatChip(
                  icon: '🛡️',
                  label: '연속실드',
                  value: '${stats.streakShield}회',
                  active: stats.streakShield > 0,
                ),
              ],
            ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final bool active;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final opacity = active ? 1.0 : 0.4;

    return Opacity(
      opacity: opacity,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 2),
          Text(
            '$label ',
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
