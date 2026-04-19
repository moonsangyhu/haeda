import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/miniroom_scene.dart';
import '../../../features/character/providers/character_provider.dart';
import '../../../features/character/providers/coin_provider.dart';
import '../../../features/character/providers/shop_provider.dart';
import '../models/room_equip.dart';
import '../models/room_slot.dart';
import '../providers/room_equip_provider.dart';
import '../widgets/slot_chip_row.dart';
import '../widgets/variant_grid.dart';

/// 미니룸 에디터 화면 — 슬롯 선택 + 아이템 그리드 + 저장.
class RoomDecoratorScreen extends ConsumerStatefulWidget {
  const RoomDecoratorScreen({super.key});

  @override
  ConsumerState<RoomDecoratorScreen> createState() =>
      _RoomDecoratorScreenState();
}

class _RoomDecoratorScreenState extends ConsumerState<RoomDecoratorScreen> {
  MiniroomSlot _selectedSlot = MiniroomSlot.wall;

  /// 편집 중 로컬 변경 — slot → itemId (null = 기본값).
  final Map<MiniroomSlot, String?> _localEdit = {};

  /// 저장 중 플래그.
  bool _saving = false;

  // ─── 헬퍼: 현재 localEdit + 서버 상태로 미니룸 equip 합성 ───

  MiniroomEquip _previewEquip(MiniroomEquip base) {
    if (_localEdit.isEmpty) return base;

    EquippedItemBrief? _slot(MiniroomSlot s) {
      if (!_localEdit.containsKey(s)) {
        return _briefFromSlot(base, s);
      }
      final id = _localEdit[s];
      if (id == null) return null;
      // owned 목록에서 brief 찾기 — 없으면 null (렌더 폴백)
      final owned = ref.read(slotItemsProvider(s)).valueOrNull ?? [];
      final shop = ref.read(slotShopProvider(s)).valueOrNull ?? [];
      try {
        final u = owned.firstWhere((ui) => ui.item.id == id);
        return EquippedItemBrief(
          id: u.item.id,
          name: u.item.name,
          category: u.item.category,
          rarity: u.item.rarity,
          assetKey: u.item.assetKey,
        );
      } catch (_) {}
      try {
        final si = shop.firstWhere((si) => si.id == id);
        return EquippedItemBrief(
          id: si.id,
          name: si.name,
          category: si.category,
          rarity: si.rarity,
          assetKey: si.assetKey,
        );
      } catch (_) {}
      return null;
    }

    return MiniroomEquip(
      wall: _slot(MiniroomSlot.wall),
      ceiling: _slot(MiniroomSlot.ceiling),
      window: _slot(MiniroomSlot.window),
      shelf: _slot(MiniroomSlot.shelf),
      plant: _slot(MiniroomSlot.plant),
      desk: _slot(MiniroomSlot.desk),
      rug: _slot(MiniroomSlot.rug),
      floor: _slot(MiniroomSlot.floor),
    );
  }

  EquippedItemBrief? _briefFromSlot(MiniroomEquip equip, MiniroomSlot slot) {
    switch (slot) {
      case MiniroomSlot.wall:
        return equip.wall;
      case MiniroomSlot.ceiling:
        return equip.ceiling;
      case MiniroomSlot.window:
        return equip.window;
      case MiniroomSlot.shelf:
        return equip.shelf;
      case MiniroomSlot.plant:
        return equip.plant;
      case MiniroomSlot.desk:
        return equip.desk;
      case MiniroomSlot.rug:
        return equip.rug;
      case MiniroomSlot.floor:
        return equip.floor;
    }
  }

  // ─── 현재 선택 슬롯의 로컬 편집 selectedItemId ───

  String? _selectedItemId(MiniroomEquip base) {
    if (_localEdit.containsKey(_selectedSlot)) {
      return _localEdit[_selectedSlot];
    }
    return _briefFromSlot(base, _selectedSlot)?.id;
  }

  // ─── 구매 핸들러 ───

  Future<bool> _handlePurchase(String itemId) async {
    final ok =
        await ref.read(shopPurchaseProvider.notifier).purchaseItem(itemId);
    if (ok) {
      // 슬롯 캐시 무효화
      ref.invalidate(slotItemsProvider(_selectedSlot));
      ref.invalidate(slotShopProvider(_selectedSlot));
    }
    return ok;
  }

  // ─── 저장 핸들러 ───

  Future<void> _save() async {
    if (_localEdit.isEmpty) {
      context.pop();
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(myMiniroomProvider.notifier).updateSlots(_localEdit);
      if (mounted) context.pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장 중 오류가 발생했어요. 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── 기본값 복원 핸들러 ───

  void _clearCurrentSlot() {
    setState(() {
      _localEdit[_selectedSlot] = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final miniroomAsync = ref.watch(myMiniroomProvider);
    final coinAsync = ref.watch(coinBalanceProvider);
    final character = ref.watch(myCharacterProvider).valueOrNull;

    final ownedAsync = ref.watch(slotItemsProvider(_selectedSlot));
    final shopAsync = ref.watch(slotShopProvider(_selectedSlot));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '내 방 꾸미기',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          // 코인 잔액 표시
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Text('🪙', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                coinAsync.when(
                  loading: () => const SizedBox(
                    width: 40,
                    height: 14,
                    child: LinearProgressIndicator(),
                  ),
                  error: (_, __) => const Text('--'),
                  data: (b) => Text(
                    '${b.balance}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: miniroomAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('미니룸 정보를 불러오지 못했어요.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () =>
                    ref.read(myMiniroomProvider.notifier).refresh(),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (base) {
          final previewEquip = _previewEquip(base);
          final selectedId = _selectedItemId(base);

          return Column(
            children: [
              // ── 미니룸 미리보기 ──
              _MiniroomPreviewCard(
                character: character,
                equip: previewEquip,
              ),

              const SizedBox(height: 8),

              // ── 슬롯 칩 행 ──
              SlotChipRow(
                selected: _selectedSlot,
                onTap: (slot) => setState(() => _selectedSlot = slot),
              ),

              const SizedBox(height: 4),

              // ── 아이템 그리드 ──
              Expanded(
                child: _buildItemGrid(
                  ownedAsync: ownedAsync.valueOrNull ?? [],
                  shopAsync: shopAsync.valueOrNull ?? [],
                  selectedId: selectedId,
                ),
              ),

              // ── 하단 액션 버튼 ──
              _BottomActionBar(
                saving: _saving,
                onClear: _clearCurrentSlot,
                onSave: _save,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildItemGrid({
    required List<dynamic> ownedAsync,
    required List<dynamic> shopAsync,
    required String? selectedId,
  }) {
    return VariantGrid(
      slot: _selectedSlot,
      owned: ref.watch(slotItemsProvider(_selectedSlot)).valueOrNull ?? [],
      shop: ref.watch(slotShopProvider(_selectedSlot)).valueOrNull ?? [],
      selectedItemId: selectedId,
      onSelect: (id) => setState(() {
        _localEdit[_selectedSlot] = id;
      }),
      onPurchase: (shopItem) => _handlePurchase(shopItem.id),
    );
  }
}

// ─── 미니룸 미리보기 카드 ───

class _MiniroomPreviewCard extends StatelessWidget {
  final dynamic character;
  final MiniroomEquip equip;

  const _MiniroomPreviewCard({
    required this.character,
    required this.equip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final previewHeight = screenHeight < 700 ? 160.0 : 200.0;
    final charSize = screenHeight < 700 ? 80.0 : 100.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13.5),
        child: MiniroomScene(
          character: character,
          height: previewHeight,
          characterSize: charSize,
          equip: equip,
        ),
      ),
    );
  }
}

// ─── 하단 액션 버튼 바 ───

class _BottomActionBar extends StatelessWidget {
  final bool saving;
  final VoidCallback onClear;
  final VoidCallback onSave;

  const _BottomActionBar({
    required this.saving,
    required this.onClear,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            // 기본값으로 TextButton
            Semantics(
              label: '현재 슬롯 기본값으로 복원',
              child: TextButton(
                onPressed: saving ? null : onClear,
                child: const Text('기본값으로'),
              ),
            ),
            const Spacer(),
            // 저장 FilledButton
            Semantics(
              label: '미니룸 변경사항 저장',
              child: FilledButton(
                onPressed: saving ? null : onSave,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(100, 44),
                ),
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '저장',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
