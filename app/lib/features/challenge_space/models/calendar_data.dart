import 'package:freezed_annotation/freezed_annotation.dart';

part 'calendar_data.freezed.dart';
part 'calendar_data.g.dart';

/// GET /challenges/{id}/calendar 응답의 members 배열 아이템.
/// UserBrief (server/app/schemas/user.py) 와 동일 구조.
@freezed
class CalendarMember with _$CalendarMember {
  const factory CalendarMember({
    required String id,
    required String nickname,
    @JsonKey(name: 'profile_image_url') String? profileImageUrl,
  }) = _CalendarMember;

  factory CalendarMember.fromJson(Map<String, dynamic> json) =>
      _$CalendarMemberFromJson(json);
}

/// GET /challenges/{id}/calendar 응답의 days 배열 아이템.
/// DayEntry (server/app/schemas/challenge.py) 와 동일 구조.
@freezed
class DayEntry with _$DayEntry {
  const factory DayEntry({
    required String date,
    @JsonKey(name: 'verified_members') required List<String> verifiedMembers,
    @JsonKey(name: 'all_completed') required bool allCompleted,
    @JsonKey(name: 'season_icon_type') String? seasonIconType,
  }) = _DayEntry;

  factory DayEntry.fromJson(Map<String, dynamic> json) =>
      _$DayEntryFromJson(json);
}

/// GET /challenges/{id}/calendar 응답의 data 필드.
/// CalendarResponse (server/app/schemas/challenge.py) 와 동일 구조.
@freezed
class CalendarData with _$CalendarData {
  const factory CalendarData({
    @JsonKey(name: 'challenge_id') required String challengeId,
    required int year,
    required int month,
    required List<CalendarMember> members,
    required List<DayEntry> days,
  }) = _CalendarData;

  factory CalendarData.fromJson(Map<String, dynamic> json) =>
      _$CalendarDataFromJson(json);
}
