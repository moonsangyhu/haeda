import 'package:freezed_annotation/freezed_annotation.dart';

part 'character_appearance.freezed.dart';
part 'character_appearance.g.dart';

@freezed
class CharacterAppearance with _$CharacterAppearance {
  const factory CharacterAppearance({
    @JsonKey(name: 'skin_tone') @Default('fair') String skinTone,
    @JsonKey(name: 'eye_style') @Default('round') String eyeStyle,
    @JsonKey(name: 'hair_style') @Default('short') String hairStyle,
  }) = _CharacterAppearance;

  factory CharacterAppearance.fromJson(Map<String, dynamic> json) =>
      _$CharacterAppearanceFromJson(json);
}
