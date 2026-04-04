import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/calendar_data.dart';

class CalendarParams {
  final String challengeId;
  final int year;
  final int month;

  const CalendarParams({
    required this.challengeId,
    required this.year,
    required this.month,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarParams &&
          runtimeType == other.runtimeType &&
          challengeId == other.challengeId &&
          year == other.year &&
          month == other.month;

  @override
  int get hashCode => Object.hash(challengeId, year, month);
}

final calendarProvider =
    FutureProvider.family<CalendarData, CalendarParams>((ref, params) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(
    '/challenges/${params.challengeId}/calendar',
    queryParameters: {
      'year': params.year,
      'month': params.month,
    },
  );
  final data = response.data as Map<String, dynamic>;
  return CalendarData.fromJson(data);
});
