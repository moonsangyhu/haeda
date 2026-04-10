import 'package:freezed_annotation/freezed_annotation.dart';

part 'member_settings.freezed.dart';
part 'member_settings.g.dart';

@freezed
class MemberSettings with _$MemberSettings {
  const factory MemberSettings({
    @JsonKey(name: 'notify_streak') required bool notifyStreak,
  }) = _MemberSettings;

  factory MemberSettings.fromJson(Map<String, dynamic> json) =>
      _$MemberSettingsFromJson(json);
}
