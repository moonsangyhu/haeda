import 'package:freezed_annotation/freezed_annotation.dart';

part 'public_challenge.freezed.dart';
part 'public_challenge.g.dart';

/// GET /challenges 응답의 creator 필드.
@freezed
class PublicChallengeCreator with _$PublicChallengeCreator {
  const factory PublicChallengeCreator({
    required String id,
    required String nickname,
    @JsonKey(name: 'profile_image_url') String? profileImageUrl,
  }) = _PublicChallengeCreator;

  factory PublicChallengeCreator.fromJson(Map<String, dynamic> json) =>
      _$PublicChallengeCreatorFromJson(json);
}

/// GET /challenges 응답의 challenges 배열 아이템.
/// api-contract.md §Public Challenge Discovery 기준.
@freezed
class PublicChallenge with _$PublicChallenge {
  const factory PublicChallenge({
    required String id,
    required String title,
    required String category,
    @JsonKey(name: 'start_date') required String startDate,
    @JsonKey(name: 'end_date') required String endDate,
    @JsonKey(name: 'member_count') required int memberCount,
    @JsonKey(name: 'photo_required') required bool photoRequired,
    required PublicChallengeCreator creator,
  }) = _PublicChallenge;

  factory PublicChallenge.fromJson(Map<String, dynamic> json) =>
      _$PublicChallengeFromJson(json);
}
