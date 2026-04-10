import 'package:freezed_annotation/freezed_annotation.dart';

part 'item_data.freezed.dart';
part 'item_data.g.dart';

/// 상점 아이템 (GET /shop/items 응답의 아이템).
@freezed
class ShopItem with _$ShopItem {
  const factory ShopItem({
    required String id,
    required String name,
    required String category,
    required int price,
    required String rarity,
    @JsonKey(name: 'asset_key') required String assetKey,
    @JsonKey(name: 'is_owned') @Default(false) bool isOwned,
  }) = _ShopItem;

  factory ShopItem.fromJson(Map<String, dynamic> json) =>
      _$ShopItemFromJson(json);
}

/// 내 아이템 (GET /me/items 응답의 아이템).
@freezed
class UserItem with _$UserItem {
  const factory UserItem({
    required String id,
    required ShopItem item,
    @JsonKey(name: 'purchased_at') required String purchasedAt,
  }) = _UserItem;

  factory UserItem.fromJson(Map<String, dynamic> json) =>
      _$UserItemFromJson(json);
}
