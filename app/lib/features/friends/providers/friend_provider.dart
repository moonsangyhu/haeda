import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/friend_data.dart';

final friendsListProvider = FutureProvider<FriendListData>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/friends');
  return FriendListData.fromJson(response.data as Map<String, dynamic>);
});

final pendingRequestsProvider =
    FutureProvider<PendingRequestsData>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/friends/requests/pending');
  return PendingRequestsData.fromJson(response.data as Map<String, dynamic>);
});

final contactMatchProvider =
    FutureProvider.family<ContactMatchData, List<String>>(
        (ref, phoneNumbers) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.post(
    '/friends/contact-match',
    data: {'phone_numbers': phoneNumbers},
  );
  return ContactMatchData.fromJson(response.data as Map<String, dynamic>);
});
