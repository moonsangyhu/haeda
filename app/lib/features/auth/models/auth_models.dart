import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_models.freezed.dart';
part 'auth_models.g.dart';

/// POST /auth/kakao 응답의 user 필드 구조.
/// api-contract.md §1 Auth 기준.
@freezed
class AuthUser with _$AuthUser {
  const factory AuthUser({
    required String id,
    String? nickname,
    @JsonKey(name: 'profile_image_url') String? profileImageUrl,
    @JsonKey(name: 'is_new') required bool isNew,
  }) = _AuthUser;

  factory AuthUser.fromJson(Map<String, dynamic> json) =>
      _$AuthUserFromJson(json);
}

/// POST /auth/kakao 응답의 data 필드 구조.
@freezed
class AuthLoginData with _$AuthLoginData {
  const factory AuthLoginData({
    @JsonKey(name: 'access_token') required String accessToken,
    @JsonKey(name: 'refresh_token') required String refreshToken,
    required AuthUser user,
  }) = _AuthLoginData;

  factory AuthLoginData.fromJson(Map<String, dynamic> json) =>
      _$AuthLoginDataFromJson(json);
}

/// PUT /auth/profile 응답의 data 필드 구조.
@freezed
class ProfileUpdateData with _$ProfileUpdateData {
  const factory ProfileUpdateData({
    required String id,
    required String nickname,
    @JsonKey(name: 'profile_image_url') String? profileImageUrl,
  }) = _ProfileUpdateData;

  factory ProfileUpdateData.fromJson(Map<String, dynamic> json) =>
      _$ProfileUpdateDataFromJson(json);
}
