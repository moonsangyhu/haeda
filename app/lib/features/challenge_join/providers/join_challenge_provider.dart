import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';

part 'join_challenge_provider.freezed.dart';
part 'join_challenge_provider.g.dart';

/// POST /challenges/{id}/join 응답의 data 필드.
/// api-contract.md §2 Challenges — 챌린지 참여 기준.
@freezed
class JoinChallengeResponse with _$JoinChallengeResponse {
  const factory JoinChallengeResponse({
    @JsonKey(name: 'challenge_id') required String challengeId,
    @JsonKey(name: 'joined_at') required String joinedAt,
  }) = _JoinChallengeResponse;

  factory JoinChallengeResponse.fromJson(Map<String, dynamic> json) =>
      _$JoinChallengeResponseFromJson(json);
}

/// POST /challenges/{id}/join 호출 Notifier.
class JoinChallengeNotifier
    extends AsyncNotifier<JoinChallengeResponse?> {
  @override
  Future<JoinChallengeResponse?> build() async => null;

  Future<JoinChallengeResponse> join(String challengeId) async {
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post<Map<String, dynamic>>(
        '/challenges/$challengeId/join',
      );
      final result = JoinChallengeResponse.fromJson(response.data!);
      state = AsyncData(result);
      return result;
    } on DioException catch (e) {
      final apiError = e.error is ApiException
          ? e.error as ApiException
          : ApiException(code: 'UNKNOWN', message: e.message ?? '오류가 발생했습니다.');
      state = AsyncError(apiError, StackTrace.current);
      rethrow;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final joinChallengeProvider =
    AsyncNotifierProvider<JoinChallengeNotifier, JoinChallengeResponse?>(
  JoinChallengeNotifier.new,
);
