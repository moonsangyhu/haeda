import 'package:dio/dio.dart';
import '../../../features/character/models/item_data.dart';
import '../models/room_equip.dart';
import '../models/room_slot.dart';

/// 미니룸 장착 관련 API 클라이언트.
/// Dio instance 는 외부에서 주입 (dioProvider 경유).
class RoomEquipApi {
  final Dio _dio;

  const RoomEquipApi(this._dio);

  /// GET /me/room/miniroom — 내 미니룸 현재 장착 상태 조회.
  Future<MiniroomEquip> getMiniroom() async {
    final response = await _dio.get('/me/room/miniroom');
    final data = response.data as Map<String, dynamic>;
    return MiniroomEquip.fromJson(data);
  }

  /// PUT /me/room/miniroom — 변경된 슬롯만 body 에 포함하여 전송.
  /// [changes] 에 null 값이 있으면 해당 슬롯을 기본값으로 복원.
  Future<MiniroomEquip> updateMiniroom(
    Map<MiniroomSlot, String?> changes,
  ) async {
    final body = <String, dynamic>{};
    for (final entry in changes.entries) {
      body[entry.key.itemIdKey] = entry.value;
    }
    final response = await _dio.put('/me/room/miniroom', data: body);
    final data = response.data as Map<String, dynamic>;
    return MiniroomEquip.fromJson(data);
  }

  /// DELETE /me/room/miniroom/{slot} — 슬롯을 기본값으로 초기화.
  Future<void> clearMiniroomSlot(MiniroomSlot slot) async {
    await _dio.delete('/me/room/miniroom/${slot.apiKey}');
  }

  /// GET /me/items?category={category} — 내가 보유한 슬롯 카테고리 아이템.
  Future<List<UserItem>> getMyItemsByCategory(String category) async {
    final response =
        await _dio.get('/me/items', queryParameters: {'category': category});
    final data = response.data as List<dynamic>;
    return data
        .map((e) => UserItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /shop/items?category={category} — 상점의 슬롯 카테고리 아이템.
  Future<List<ShopItem>> getShopItemsByCategory(String category) async {
    final response = await _dio
        .get('/shop/items', queryParameters: {'category': category});
    final data = response.data as List<dynamic>;
    return data
        .map((e) => ShopItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
