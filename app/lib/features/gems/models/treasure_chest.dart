// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'chest_state.dart';

part 'treasure_chest.freezed.dart';
part 'treasure_chest.g.dart';

@freezed
class TreasureChest with _$TreasureChest {
  const factory TreasureChest({
    required ChestState state,
    @JsonKey(name: 'armed_at') DateTime? armedAt,
    @JsonKey(name: 'openable_at') DateTime? openableAt,
    @JsonKey(name: 'opened_at') DateTime? openedAt,
    @JsonKey(name: 'reward_gems') required int rewardGems,
    @JsonKey(name: 'remaining_seconds') int? remainingSeconds,
  }) = _TreasureChest;

  factory TreasureChest.fromJson(Map<String, dynamic> json) =>
      _$TreasureChestFromJson(json);
}
