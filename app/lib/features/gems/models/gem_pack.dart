// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'gem_pack.freezed.dart';
part 'gem_pack.g.dart';

@freezed
class GemPack with _$GemPack {
  const factory GemPack({
    required String id,
    required int gems,
    @JsonKey(name: 'bonus_gems') required int bonusGems,
    @JsonKey(name: 'price_krw') required int priceKrw,
  }) = _GemPack;

  factory GemPack.fromJson(Map<String, dynamic> json) =>
      _$GemPackFromJson(json);
}
