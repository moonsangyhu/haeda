import 'package:freezed_annotation/freezed_annotation.dart';
import 'verification_data.dart';

part 'comment_data.freezed.dart';
part 'comment_data.g.dart';

/// GET /verifications/{id} 응답의 comments[].author
@freezed
class CommentAuthor with _$CommentAuthor {
  const factory CommentAuthor({
    required String id,
    required String nickname,
    @JsonKey(name: 'profile_image_url') String? profileImageUrl,
  }) = _CommentAuthor;

  factory CommentAuthor.fromJson(Map<String, dynamic> json) =>
      _$CommentAuthorFromJson(json);
}

/// GET /verifications/{id} 응답의 comments[] 아이템
@freezed
class CommentItem with _$CommentItem {
  const factory CommentItem({
    required String id,
    required CommentAuthor author,
    required String content,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _CommentItem;

  factory CommentItem.fromJson(Map<String, dynamic> json) =>
      _$CommentItemFromJson(json);
}

/// GET /verifications/{id} 응답의 data 필드
@freezed
class VerificationDetail with _$VerificationDetail {
  const factory VerificationDetail({
    required String id,
    @JsonKey(name: 'challenge_id') required String challengeId,
    required VerificationUser user,
    required String date,
    @JsonKey(name: 'photo_url') String? photoUrl,
    @JsonKey(name: 'diary_text') required String diaryText,
    required List<CommentItem> comments,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _VerificationDetail;

  factory VerificationDetail.fromJson(Map<String, dynamic> json) =>
      _$VerificationDetailFromJson(json);
}
