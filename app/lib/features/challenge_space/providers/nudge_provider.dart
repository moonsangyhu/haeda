import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../notifications/models/notification_data.dart';
import '../../notifications/providers/notification_provider.dart';

/// Sends a nudge to a challenge member. Throws [DioException] (with [ApiException])
/// on failure so callers can inspect the error code.
Future<void> sendNudge(
  WidgetRef ref,
  String challengeId,
  String receiverId,
) async {
  final dio = ref.read(dioProvider);
  await dio.post(
    '/challenges/$challengeId/nudge',
    data: {'receiver_id': receiverId},
  );
}

/// Returns today's nudge notifications received for a specific challenge.
/// Used to show the nudge banner in the challenge space screen.
final receivedNudgesProvider =
    FutureProvider.family<List<NotificationItem>, String>((ref, challengeId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(
    '/notifications',
    queryParameters: {'limit': 10, 'offset': 0},
  );
  final data = NotificationListData.fromJson(response.data as Map<String, dynamic>);
  final today = DateTime.now().toIso8601String().substring(0, 10);
  return data.notifications.where((n) {
    final isNudge = n.type == 'nudge';
    final isSameChallenge = n.dataJson?['challenge_id'] == challengeId;
    final isToday = n.createdAt.substring(0, 10) == today;
    return isNudge && isSameChallenge && isToday;
  }).toList();
});
