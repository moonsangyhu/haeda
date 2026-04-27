import 'package:json_annotation/json_annotation.dart';

enum DayStatus {
  @JsonValue('success')
  success,
  @JsonValue('failure')
  failure,
  @JsonValue('today_pending')
  todayPending,
  @JsonValue('future')
  future,
  @JsonValue('before_join')
  beforeJoin,
}
