import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../challenge_space/models/challenge_detail.dart';

/// GET /challenges/invite/{code} — 초대 코드로 챌린지 미리보기 조회.
/// api-contract.md §2 Challenges — 초대 코드로 챌린지 조회 기준.
/// 응답 구조는 챌린지 상세와 동일하므로 ChallengeDetail 모델 재사용.
/// 단, 초대 미리보기에서는 is_member 필드가 없을 수 있으므로 주의.
final invitePreviewProvider =
    FutureProvider.family<ChallengeDetail, String>((ref, code) async {
  final dio = ref.watch(dioProvider);
  final response =
      await dio.get<Map<String, dynamic>>('/challenges/invite/$code');
  // ResponseInterceptor가 envelope을 벗겨주므로 response.data가 data 필드 내용.
  return ChallengeDetail.fromJson(response.data!);
});
