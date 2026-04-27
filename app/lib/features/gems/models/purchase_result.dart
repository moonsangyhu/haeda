// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'purchase_result.freezed.dart';
part 'purchase_result.g.dart';

@freezed
class PurchaseResult with _$PurchaseResult {
  const factory PurchaseResult({
    @JsonKey(name: 'awarded_gems') required int awardedGems,
    required int balance,
    @JsonKey(name: 'pack_id') required String packId,
  }) = _PurchaseResult;

  factory PurchaseResult.fromJson(Map<String, dynamic> json) =>
      _$PurchaseResultFromJson(json);
}
