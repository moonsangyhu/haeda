// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'day_status.dart';

part 'streak_calendar.freezed.dart';
part 'streak_calendar.g.dart';

@freezed
class StreakDay with _$StreakDay {
  const factory StreakDay({
    required DateTime date,
    required DayStatus status,
  }) = _StreakDay;

  factory StreakDay.fromJson(Map<String, dynamic> json) =>
      _$StreakDayFromJson(json);
}

@freezed
class StreakCalendar with _$StreakCalendar {
  const factory StreakCalendar({
    required int streak,
    @JsonKey(name: 'first_join_date') DateTime? firstJoinDate,
    required int year,
    required int month,
    required List<StreakDay> days,
  }) = _StreakCalendar;

  factory StreakCalendar.fromJson(Map<String, dynamic> json) =>
      _$StreakCalendarFromJson(json);
}
