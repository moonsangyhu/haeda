import 'package:freezed_annotation/freezed_annotation.dart';

part 'challenge_summary.freezed.dart';
part 'challenge_summary.g.dart';

/// GET /me/challenges 응답의 challenges 배열 아이템.
/// api-contract.md §3 My Page 기준.
@freezed
class ChallengeSummary with _$ChallengeSummary {
  const factory ChallengeSummary({
    required String id,
    required String title,
    required String category,
    @JsonKey(name: 'start_date') required String startDate,
    @JsonKey(name: 'end_date') required String endDate,
    required String status,
    @JsonKey(name: 'member_count') required int memberCount,
    @JsonKey(name: 'achievement_rate') required double achievementRate,
    String? badge,
    @JsonKey(name: 'today_verified') @Default(false) bool todayVerified,
  }) = _ChallengeSummary;

  factory ChallengeSummary.fromJson(Map<String, dynamic> json) =>
      _$ChallengeSummaryFromJson(json);
}
