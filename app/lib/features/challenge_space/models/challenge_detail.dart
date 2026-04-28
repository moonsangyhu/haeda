import 'package:freezed_annotation/freezed_annotation.dart';

part 'challenge_detail.freezed.dart';
part 'challenge_detail.g.dart';

/// GET /challenges/{id} 응답의 data 필드.
/// api-contract.md §2 Challenges — 챌린지 상세 기준.
@freezed
class MemberBrief with _$MemberBrief {
  const factory MemberBrief({
    required String id,
    required String nickname,
    @JsonKey(name: 'profile_image_url') String? profileImageUrl,
  }) = _MemberBrief;

  factory MemberBrief.fromJson(Map<String, dynamic> json) =>
      _$MemberBriefFromJson(json);
}

@freezed
class ChallengeDetail with _$ChallengeDetail {
  const factory ChallengeDetail({
    required String id,
    required String title,
    String? description,
    required String category,
    @JsonKey(name: 'start_date') required String startDate,
    @JsonKey(name: 'end_date') required String endDate,
    @JsonKey(name: 'verification_frequency')
    required Map<String, dynamic> verificationFrequency,
    @JsonKey(name: 'photo_required') required bool photoRequired,
    @JsonKey(name: 'day_cutoff_hour') @Default(0) int dayCutoffHour,
    @JsonKey(name: 'invite_code') required String inviteCode,
    required String status,
    required MemberBrief creator,
    @JsonKey(name: 'member_count') required int memberCount,
    @JsonKey(name: 'is_member') required bool isMember,
    @JsonKey(name: 'is_creator') @Default(false) bool isCreator,
    @Default('🎯') String icon,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _ChallengeDetail;

  factory ChallengeDetail.fromJson(Map<String, dynamic> json) =>
      _$ChallengeDetailFromJson(json);
}
