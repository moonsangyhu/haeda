import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/challenge_summary.dart';

final myChallengesProvider = FutureProvider<List<ChallengeSummary>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/me/challenges');
  // ResponseInterceptor가 data 필드를 추출한 후의 값
  final data = response.data as Map<String, dynamic>;
  final challenges = data['challenges'] as List<dynamic>;
  return challenges
      .map((e) => ChallengeSummary.fromJson(e as Map<String, dynamic>))
      .toList();
});
