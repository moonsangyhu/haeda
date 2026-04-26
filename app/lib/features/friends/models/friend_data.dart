import 'package:freezed_annotation/freezed_annotation.dart';

part 'friend_data.freezed.dart';
part 'friend_data.g.dart';

@freezed
class FriendItem with _$FriendItem {
  const factory FriendItem({
    @JsonKey(name: 'user_id') required String userId,
    required String nickname,
    @JsonKey(name: 'profile_image_url') String? profileImageUrl,
  }) = _FriendItem;

  factory FriendItem.fromJson(Map<String, dynamic> json) =>
      _$FriendItemFromJson(json);
}

@freezed
class FriendListData with _$FriendListData {
  const factory FriendListData({
    required List<FriendItem> friends,
  }) = _FriendListData;

  factory FriendListData.fromJson(Map<String, dynamic> json) =>
      _$FriendListDataFromJson(json);
}

@freezed
class FriendRequestUser with _$FriendRequestUser {
  const factory FriendRequestUser({
    required String id,
    required String nickname,
    @JsonKey(name: 'profile_image_url') String? profileImageUrl,
  }) = _FriendRequestUser;

  factory FriendRequestUser.fromJson(Map<String, dynamic> json) =>
      _$FriendRequestUserFromJson(json);
}

@freezed
class FriendRequestItem with _$FriendRequestItem {
  const factory FriendRequestItem({
    required String id,
    required FriendRequestUser user,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _FriendRequestItem;

  factory FriendRequestItem.fromJson(Map<String, dynamic> json) =>
      _$FriendRequestItemFromJson(json);
}

@freezed
class PendingRequestsData with _$PendingRequestsData {
  const factory PendingRequestsData({
    required List<FriendRequestItem> requests,
  }) = _PendingRequestsData;

  factory PendingRequestsData.fromJson(Map<String, dynamic> json) =>
      _$PendingRequestsDataFromJson(json);
}

@freezed
class ContactMatchItem with _$ContactMatchItem {
  const factory ContactMatchItem({
    @JsonKey(name: 'user_id') required String userId,
    required String nickname,
    required String discriminator,
    @JsonKey(name: 'profile_image_url') String? profileImageUrl,
    @JsonKey(name: 'friendship_status') String? friendshipStatus,
  }) = _ContactMatchItem;

  factory ContactMatchItem.fromJson(Map<String, dynamic> json) =>
      _$ContactMatchItemFromJson(json);
}

@freezed
class ContactMatchData with _$ContactMatchData {
  const factory ContactMatchData({
    required List<ContactMatchItem> matches,
  }) = _ContactMatchData;

  factory ContactMatchData.fromJson(Map<String, dynamic> json) =>
      _$ContactMatchDataFromJson(json);
}
