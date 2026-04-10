import 'package:freezed_annotation/freezed_annotation.dart';

part 'feed_item_data.freezed.dart';
part 'feed_item_data.g.dart';

@freezed
class FeedActor with _$FeedActor {
  const factory FeedActor({
    required String id,
    required String nickname,
    @JsonKey(name: 'profile_image_url') String? profileImageUrl,
  }) = _FeedActor;

  factory FeedActor.fromJson(Map<String, dynamic> json) =>
      _$FeedActorFromJson(json);
}

@freezed
class FeedItemData with _$FeedItemData {
  const factory FeedItemData({
    required String id,
    required FeedActor actor,
    required String type,
    @JsonKey(name: 'challenge_title') required String challengeTitle,
    @JsonKey(name: 'challenge_id') required String challengeId,
    @JsonKey(name: 'photo_urls') List<String>? photoUrls,
    @JsonKey(name: 'diary_text') String? diaryText,
    @JsonKey(name: 'clap_count') required int clapCount,
    @JsonKey(name: 'has_clapped') required bool hasClapped,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _FeedItemData;

  factory FeedItemData.fromJson(Map<String, dynamic> json) =>
      _$FeedItemDataFromJson(json);
}

@freezed
class FeedListData with _$FeedListData {
  const factory FeedListData({
    required List<FeedItemData> items,
    @JsonKey(name: 'next_cursor') String? nextCursor,
  }) = _FeedListData;

  factory FeedListData.fromJson(Map<String, dynamic> json) =>
      _$FeedListDataFromJson(json);
}
