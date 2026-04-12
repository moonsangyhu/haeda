import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../models/challenge_create_response.dart';

/// POST /challenges 요청 바디.
class ChallengeCreateRequest {
  final String title;
  final String? description;
  final String category;
  final String startDate;
  final String endDate;
  final Map<String, dynamic> verificationFrequency;
  final bool photoRequired;
  final int dayCutoffHour;

  const ChallengeCreateRequest({
    required this.title,
    this.description,
    required this.category,
    required this.startDate,
    required this.endDate,
    required this.verificationFrequency,
    required this.photoRequired,
    this.dayCutoffHour = 0,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        if (description != null && description!.isNotEmpty)
          'description': description,
        'category': category,
        'start_date': startDate,
        'end_date': endDate,
        'verification_frequency': verificationFrequency,
        'photo_required': photoRequired,
        'day_cutoff_hour': dayCutoffHour,
      };
}

/// Step 1 폼 데이터를 임시 보관하는 provider (Step 1 → Step 2 전달용).
final challengeStep1DataProvider =
    StateProvider<Map<String, String?>>((ref) => {});

/// POST /challenges 호출 결과 provider.
/// [ChallengeCreateNotifier]를 통해 생성 요청을 실행한다.
class ChallengeCreateNotifier
    extends AsyncNotifier<ChallengeCreateResponse?> {
  @override
  Future<ChallengeCreateResponse?> build() async => null;

  Future<ChallengeCreateResponse> createChallenge(
      ChallengeCreateRequest request) async {
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post<Map<String, dynamic>>(
        '/challenges',
        data: request.toJson(),
      );
      final result =
          ChallengeCreateResponse.fromJson(response.data!);
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

final challengeCreateProvider =
    AsyncNotifierProvider<ChallengeCreateNotifier, ChallengeCreateResponse?>(
  ChallengeCreateNotifier.new,
);
