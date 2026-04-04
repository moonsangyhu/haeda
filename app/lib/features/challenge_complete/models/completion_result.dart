import 'package:freezed_annotation/freezed_annotation.dart';

part 'completion_result.freezed.dart';
part 'completion_result.g.dart';

/// GET /challenges/{id}/completion 응답의 data 필드.
/// api-contract.md §5 Challenge Completion 기준.
@freezed
class MyResult with _$MyResult {
  const factory MyResult({
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'achievement_rate') required double achievementRate,
    @JsonKey(name: 'verified_days') required int verifiedDays,
    @JsonKey(name: 'expected_days') required int expectedDays,
    String? badge,
  }) = _MyResult;

  factory MyResult.fromJson(Map<String, dynamic> json) =>
      _$MyResultFromJson(json);
}

@freezed
class MemberResult with _$MemberResult {
  const factory MemberResult({
    @JsonKey(name: 'user_id') required String userId,
    required String nickname,
    @JsonKey(name: 'profile_image_url') String? profileImageUrl,
    @JsonKey(name: 'achievement_rate') required double achievementRate,
    @JsonKey(name: 'verified_days') required int verifiedDays,
    String? badge,
  }) = _MemberResult;

  factory MemberResult.fromJson(Map<String, dynamic> json) =>
      _$MemberResultFromJson(json);
}

@freezed
class CalendarSummary with _$CalendarSummary {
  const factory CalendarSummary({
    @JsonKey(name: 'total_days') required int totalDays,
    @JsonKey(name: 'all_completed_days') required int allCompletedDays,
    @JsonKey(name: 'season_icon_types') required List<String> seasonIconTypes,
  }) = _CalendarSummary;

  factory CalendarSummary.fromJson(Map<String, dynamic> json) =>
      _$CalendarSummaryFromJson(json);
}

@freezed
class CompletionResult with _$CompletionResult {
  const factory CompletionResult({
    @JsonKey(name: 'challenge_id') required String challengeId,
    required String title,
    required String category,
    @JsonKey(name: 'start_date') required String startDate,
    @JsonKey(name: 'end_date') required String endDate,
    @JsonKey(name: 'total_days') required int totalDays,
    @JsonKey(name: 'my_result') required MyResult myResult,
    required List<MemberResult> members,
    @JsonKey(name: 'day_completions') required int dayCompletions,
    @JsonKey(name: 'calendar_summary') required CalendarSummary calendarSummary,
  }) = _CompletionResult;

  factory CompletionResult.fromJson(Map<String, dynamic> json) =>
      _$CompletionResultFromJson(json);
}
