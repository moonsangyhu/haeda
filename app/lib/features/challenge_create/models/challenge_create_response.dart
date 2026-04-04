import 'package:freezed_annotation/freezed_annotation.dart';

part 'challenge_create_response.freezed.dart';
part 'challenge_create_response.g.dart';

/// POST /challenges 응답의 data 필드 구조.
/// api-contract.md §2 Challenges — 챌린지 생성 기준.
@freezed
class ChallengeCreateResponse with _$ChallengeCreateResponse {
  const factory ChallengeCreateResponse({
    required String id,
    required String title,
    String? description,
    required String category,
    @JsonKey(name: 'start_date') required String startDate,
    @JsonKey(name: 'end_date') required String endDate,
    @JsonKey(name: 'verification_frequency')
    required Map<String, dynamic> verificationFrequency,
    @JsonKey(name: 'photo_required') required bool photoRequired,
    @JsonKey(name: 'is_public') required bool isPublic,
    @JsonKey(name: 'invite_code') required String inviteCode,
    required String status,
    required ChallengeCreatorBrief creator,
    @JsonKey(name: 'member_count') required int memberCount,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _ChallengeCreateResponse;

  factory ChallengeCreateResponse.fromJson(Map<String, dynamic> json) =>
      _$ChallengeCreateResponseFromJson(json);
}

@freezed
class ChallengeCreatorBrief with _$ChallengeCreatorBrief {
  const factory ChallengeCreatorBrief({
    required String id,
    required String nickname,
    @JsonKey(name: 'profile_image_url') String? profileImageUrl,
  }) = _ChallengeCreatorBrief;

  factory ChallengeCreatorBrief.fromJson(Map<String, dynamic> json) =>
      _$ChallengeCreatorBriefFromJson(json);
}
