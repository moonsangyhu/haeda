import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/user_stats.dart';

final userStatsProvider = FutureProvider<UserStats>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/me/stats');
  // ResponseInterceptor unwraps the "data" envelope
  final data = response.data as Map<String, dynamic>;
  return UserStats.fromJson(data);
});
