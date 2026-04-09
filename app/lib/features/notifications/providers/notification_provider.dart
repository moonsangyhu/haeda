import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/notification_data.dart';

final notificationListProvider =
    FutureProvider.family<NotificationListData, int>((ref, offset) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(
    '/notifications',
    queryParameters: {'limit': 20, 'offset': offset},
  );
  return NotificationListData.fromJson(response.data as Map<String, dynamic>);
});

final unreadCountProvider = FutureProvider<int>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/notifications/unread-count');
  final data = response.data as Map<String, dynamic>;
  return data['count'] as int;
});
