import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../my_page/models/challenge_summary.dart';
import '../../my_page/providers/my_challenges_provider.dart';

/// 사용자가 가장 최근에 인증한 챌린지 (없으면 null).
///
/// 서버가 `last_verified_at DESC NULLS LAST, start_date DESC` 로 정렬해 주므로
/// `myChallengesProvider` 응답의 첫 항목을 그대로 반환한다.
final mostRecentChallengeProvider = Provider<ChallengeSummary?>((ref) {
  final list = ref.watch(myChallengesProvider).valueOrNull;
  if (list == null || list.isEmpty) return null;
  return list.first;
});
