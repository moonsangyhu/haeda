import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../features/character/models/item_data.dart';
import '../api/room_equip_api.dart';
import '../models/room_equip.dart';
import '../models/room_slot.dart';

// ─── API instance provider ───

final _roomEquipApiProvider = Provider<RoomEquipApi>((ref) {
  return RoomEquipApi(ref.watch(dioProvider));
});

// ─── 내 미니룸 장착 상태 ───

/// 내 미니룸 현재 장착 상태 — 낙관적 업데이트로 즉시 반영.
final myMiniroomProvider =
    StateNotifierProvider<MyMiniroomNotifier, AsyncValue<MiniroomEquip>>((ref) {
  return MyMiniroomNotifier(ref.watch(_roomEquipApiProvider));
});

class MyMiniroomNotifier extends StateNotifier<AsyncValue<MiniroomEquip>> {
  final RoomEquipApi _api;

  MyMiniroomNotifier(this._api) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final equip = await _api.getMiniroom();
      state = AsyncValue.data(equip);
    } catch (_) {
      state = AsyncValue.data(MiniroomEquip.empty());
    }
  }

  /// 슬롯 변경 저장 — 낙관적 업데이트 후 API 호출, 에러시 롤백.
  Future<void> updateSlots(Map<MiniroomSlot, String?> changes) async {
    final prev = state.valueOrNull ?? MiniroomEquip.empty();

    // 낙관적 업데이트는 현재 state 에서 null 처리 (API 응답 후 실제 반영)
    try {
      final updated = await _api.updateMiniroom(changes);
      state = AsyncValue.data(updated);
    } catch (e) {
      // 롤백
      state = AsyncValue.data(prev);
      rethrow;
    }
  }

  /// 단일 슬롯 초기화 (DELETE).
  Future<void> clearSlot(MiniroomSlot slot) async {
    final prev = state.valueOrNull ?? MiniroomEquip.empty();
    try {
      await _api.clearMiniroomSlot(slot);
      await _load();
    } catch (e) {
      state = AsyncValue.data(prev);
      rethrow;
    }
  }

  /// 강제 새로고침.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _load();
  }
}

// ─── 슬롯별 보유 아이템 ───

/// 특정 슬롯에 장착 가능한 내 보유 아이템 목록.
final slotItemsProvider =
    FutureProvider.family<List<UserItem>, MiniroomSlot>((ref, slot) async {
  final api = ref.watch(_roomEquipApiProvider);
  try {
    return await api.getMyItemsByCategory(slot.category);
  } catch (_) {
    return [];
  }
});

// ─── 슬롯별 상점 아이템 ───

/// 특정 슬롯의 상점 아이템 목록 (구매 가능 여부 포함).
final slotShopProvider =
    FutureProvider.family<List<ShopItem>, MiniroomSlot>((ref, slot) async {
  final api = ref.watch(_roomEquipApiProvider);
  try {
    return await api.getShopItemsByCategory(slot.category);
  } catch (_) {
    return [];
  }
});
