import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_stats.freezed.dart';
part 'user_stats.g.dart';

@freezed
class UserStats with _$UserStats {
  const factory UserStats({
    required int streak,
    @JsonKey(name: 'verified_today') required bool verifiedToday,
    @JsonKey(name: 'active_challenges') required int activeChallenges,
    @JsonKey(name: 'completed_challenges') required int completedChallenges,
    required int gems,
  }) = _UserStats;

  factory UserStats.fromJson(Map<String, dynamic> json) =>
      _$UserStatsFromJson(json);
}
