import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/feed_item_data.dart';

/// Feed list provider. Parameter is cursor (null for first page).
final feedListProvider =
    FutureProvider.family<FeedListData, String?>((ref, cursor) async {
  final dio = ref.watch(dioProvider);
  final queryParams = <String, dynamic>{'limit': 20};
  if (cursor != null) queryParams['cursor'] = cursor;
  final response = await dio.get('/feed', queryParameters: queryParams);
  return FeedListData.fromJson(response.data as Map<String, dynamic>);
});

/// Toggle clap on a feed item. Returns updated clap state.
Future<Map<String, dynamic>> toggleClap(
  dynamic dio,
  String feedItemId,
) async {
  final response = await dio.post('/feed/$feedItemId/clap');
  return response.data as Map<String, dynamic>;
}
