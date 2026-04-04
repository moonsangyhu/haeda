import 'package:freezed_annotation/freezed_annotation.dart';

part 'verification_data.freezed.dart';
part 'verification_data.g.dart';

/// POST /challenges/{id}/verifications 응답의 data 필드.
@freezed
class VerificationCreateResult with _$VerificationCreateResult {
  const factory VerificationCreateResult({
    required String id,
    required String date,
    @JsonKey(name: 'photo_url') String? photoUrl,
    @JsonKey(name: 'diary_text') required String diaryText,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'day_completed') required bool dayCompleted,
    @JsonKey(name: 'season_icon_type') String? seasonIconType,
  }) = _VerificationCreateResult;

  factory VerificationCreateResult.fromJson(Map<String, dynamic> json) =>
      _$VerificationCreateResultFromJson(json);
}

/// GET /challenges/{id}/verifications/{date} 응답의 verifications[].user
@freezed
class VerificationUser with _$VerificationUser {
  const factory VerificationUser({
    required String id,
    required String nickname,
    @JsonKey(name: 'profile_image_url') String? profileImageUrl,
  }) = _VerificationUser;

  factory VerificationUser.fromJson(Map<String, dynamic> json) =>
      _$VerificationUserFromJson(json);
}

/// GET /challenges/{id}/verifications/{date} 응답의 verifications[] 아이템.
@freezed
class VerificationItem with _$VerificationItem {
  const factory VerificationItem({
    required String id,
    required VerificationUser user,
    @JsonKey(name: 'photo_url') String? photoUrl,
    @JsonKey(name: 'diary_text') required String diaryText,
    @JsonKey(name: 'comment_count') required int commentCount,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _VerificationItem;

  factory VerificationItem.fromJson(Map<String, dynamic> json) =>
      _$VerificationItemFromJson(json);
}

/// GET /challenges/{id}/verifications/{date} 응답의 data 필드.
@freezed
class DailyVerifications with _$DailyVerifications {
  const factory DailyVerifications({
    required String date,
    @JsonKey(name: 'all_completed') required bool allCompleted,
    @JsonKey(name: 'season_icon_type') String? seasonIconType,
    required List<VerificationItem> verifications,
  }) = _DailyVerifications;

  factory DailyVerifications.fromJson(Map<String, dynamic> json) =>
      _$DailyVerificationsFromJson(json);
}
