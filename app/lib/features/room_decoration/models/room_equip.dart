import 'package:freezed_annotation/freezed_annotation.dart';

part 'room_equip.freezed.dart';
part 'room_equip.g.dart';

/// GET /me/room/miniroom 응답의 슬롯별 장착 아이템 요약.
/// CharacterSlot 패턴과 동일하게 설계.
@freezed
class EquippedItemBrief with _$EquippedItemBrief {
  const factory EquippedItemBrief({
    required String id,
    required String name,
    required String category,
    required String rarity,
    @JsonKey(name: 'asset_key') required String assetKey,
    @JsonKey(name: 'is_limited') @Default(false) bool isLimited,
  }) = _EquippedItemBrief;

  factory EquippedItemBrief.fromJson(Map<String, dynamic> json) =>
      _$EquippedItemBriefFromJson(json);
}

/// GET /me/room/miniroom 응답의 data 필드.
/// 각 슬롯이 null 이면 기본 렌더(미장착).
@freezed
class MiniroomEquip with _$MiniroomEquip {
  const MiniroomEquip._();

  const factory MiniroomEquip({
    EquippedItemBrief? wall,
    EquippedItemBrief? ceiling,
    EquippedItemBrief? window,
    EquippedItemBrief? shelf,
    EquippedItemBrief? plant,
    EquippedItemBrief? desk,
    EquippedItemBrief? rug,
    EquippedItemBrief? floor,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _MiniroomEquip;

  factory MiniroomEquip.fromJson(Map<String, dynamic> json) =>
      _$MiniroomEquipFromJson(json);

  /// 모든 슬롯이 null인 빈 상태 helper.
  factory MiniroomEquip.empty() => const MiniroomEquip();
}
