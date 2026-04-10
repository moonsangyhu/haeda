import 'package:freezed_annotation/freezed_annotation.dart';

part 'character_data.freezed.dart';
part 'character_data.g.dart';

/// 장착된 슬롯 아이템 정보.
@freezed
class CharacterSlot with _$CharacterSlot {
  const factory CharacterSlot({
    required String id,
    required String name,
    @JsonKey(name: 'asset_key') required String assetKey,
    required String rarity,
  }) = _CharacterSlot;

  factory CharacterSlot.fromJson(Map<String, dynamic> json) =>
      _$CharacterSlotFromJson(json);
}

/// GET /me/character 응답의 data 필드.
/// 각 슬롯은 null이면 미착용 상태.
/// skinTone, eyeStyle, hairStyle은 외형 커스터마이징 필드.
@freezed
class CharacterData with _$CharacterData {
  const CharacterData._();

  const factory CharacterData({
    CharacterSlot? hat,
    CharacterSlot? top,
    CharacterSlot? bottom,
    CharacterSlot? shoes,
    CharacterSlot? accessory,
    @JsonKey(name: 'skin_tone') @Default('fair') String skinTone,
    @JsonKey(name: 'eye_style') @Default('round') String eyeStyle,
    @JsonKey(name: 'hair_style') @Default('short') String hairStyle,
  }) = _CharacterData;

  factory CharacterData.fromJson(Map<String, dynamic> json) =>
      _$CharacterDataFromJson(json);
}
