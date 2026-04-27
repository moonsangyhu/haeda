import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/streak_calendar.dart';

typedef YearMonth = ({int year, int month});

final streakCalendarProvider =
    FutureProvider.family<StreakCalendar, YearMonth>((ref, ym) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(
    '/me/streak/calendar',
    queryParameters: {'year': ym.year, 'month': ym.month},
  );
  final data = response.data as Map<String, dynamic>;
  return StreakCalendar.fromJson(data);
});
