import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/public_challenge.dart';

/// 선택된 카테고리 필터. null = 전체.
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

/// GET /challenges 응답으로 공개 챌린지 목록 반환.
/// selectedCategoryProvider 변경 시 자동으로 재조회.
final publicChallengesProvider =
    FutureProvider<List<PublicChallenge>>((ref) async {
  final dio = ref.watch(dioProvider);
  final category = ref.watch(selectedCategoryProvider);

  final queryParams = <String, dynamic>{
    'limit': 20,
    if (category != null) 'category': category,
  };

  final response = await dio.get(
    '/challenges',
    queryParameters: queryParams,
  );

  // ResponseInterceptor가 data 필드를 추출한 후의 값
  final data = response.data as Map<String, dynamic>;
  final challenges = data['challenges'] as List<dynamic>;
  return challenges
      .map((e) => PublicChallenge.fromJson(e as Map<String, dynamic>))
      .toList();
});
