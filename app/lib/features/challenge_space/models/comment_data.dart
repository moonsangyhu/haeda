import 'package:freezed_annotation/freezed_annotation.dart';
import '../../character/models/character_data.dart';

part 'comment_data.freezed.dart';
part 'comment_data.g.dart';

/// GET /verifications/{id} 응답의 comments[].author
@freezed
class CommentAuthor with _$CommentAuthor {
  const factory CommentAuthor({
    required String id,
    required String nickname,
    @JsonKey(name: 'profile_image_url') String? profileImageUrl,
    CharacterData? character,
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
