import 'package:freezed_annotation/freezed_annotation.dart';

part 'nudge_data.freezed.dart';
part 'nudge_data.g.dart';

@freezed
class NudgeSender with _$NudgeSender {
  const factory NudgeSender({
    required String id,
    required String nickname,
    @JsonKey(name: 'profile_image_url') String? profileImageUrl,
  }) = _NudgeSender;

  factory NudgeSender.fromJson(Map<String, dynamic> json) =>
      _$NudgeSenderFromJson(json);
}

@freezed
class NudgeReceived with _$NudgeReceived {
  const factory NudgeReceived({
    required String id,
    required NudgeSender sender,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _NudgeReceived;

  factory NudgeReceived.fromJson(Map<String, dynamic> json) =>
      _$NudgeReceivedFromJson(json);
}
