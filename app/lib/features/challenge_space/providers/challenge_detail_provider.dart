import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/challenge_detail.dart';

final challengeDetailProvider =
    FutureProvider.family<ChallengeDetail, String>((ref, challengeId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/challenges/$challengeId');
  final data = response.data as Map<String, dynamic>;
  return ChallengeDetail.fromJson(data);
});
