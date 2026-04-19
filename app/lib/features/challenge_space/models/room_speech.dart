import 'package:freezed_annotation/freezed_annotation.dart';

part 'room_speech.freezed.dart';
part 'room_speech.g.dart';

@freezed
class RoomSpeech with _$RoomSpeech {
  const factory RoomSpeech({
    @JsonKey(name: 'user_id') required String userId,
    required String nickname,
    required String content,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'expires_at') required DateTime expiresAt,
  }) = _RoomSpeech;

  factory RoomSpeech.fromJson(Map<String, dynamic> json) =>
      _$RoomSpeechFromJson(json);
}
