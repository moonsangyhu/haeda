import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/verification_data.dart';

/// GET /challenges/{id}/verifications/{date} 파라미터
class DailyVerificationParams {
  final String challengeId;
  final String date; // YYYY-MM-DD

  const DailyVerificationParams({
    required this.challengeId,
    required this.date,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyVerificationParams &&
          runtimeType == other.runtimeType &&
          challengeId == other.challengeId &&
          date == other.date;

  @override
  int get hashCode => Object.hash(challengeId, date);
}

/// 날짜별 인증 현황 조회
final dailyVerificationsProvider = FutureProvider.family<DailyVerifications,
    DailyVerificationParams>((ref, params) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(
    '/challenges/${params.challengeId}/verifications/${params.date}',
  );
  final data = response.data as Map<String, dynamic>;
  return DailyVerifications.fromJson(data);
});

/// 인증 제출 상태
class VerificationSubmitState {
  final bool isLoading;
  final VerificationCreateResult? result;
  final String? errorMessage;

  const VerificationSubmitState({
    this.isLoading = false,
    this.result,
    this.errorMessage,
  });

  VerificationSubmitState copyWith({
    bool? isLoading,
    VerificationCreateResult? result,
    String? errorMessage,
  }) {
    return VerificationSubmitState(
      isLoading: isLoading ?? this.isLoading,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class VerificationSubmitNotifier
    extends StateNotifier<VerificationSubmitState> {
  final Dio _dio;
  final String challengeId;

  VerificationSubmitNotifier(this._dio, this.challengeId)
      : super(const VerificationSubmitState());

  Future<VerificationCreateResult?> submit({
    required String diaryText,
    List<int>? photoBytes,
    String? photoFileName,
  }) async {
    state = const VerificationSubmitState(isLoading: true);

    try {
      final formData = FormData.fromMap({
        'diary_text': diaryText,
        if (photoBytes != null)
          'photo': MultipartFile.fromBytes(
            photoBytes,
            filename: photoFileName ?? 'photo.jpg',
          ),
      });

      final response = await _dio.post(
        '/challenges/$challengeId/verifications',
        data: formData,
      );
      final data = response.data as Map<String, dynamic>;
      final result = VerificationCreateResult.fromJson(data);
      state = VerificationSubmitState(result: result);
      return result;
    } on DioException catch (e) {
      final message = _extractErrorMessage(e);
      state = VerificationSubmitState(errorMessage: message);
      return null;
    } catch (e) {
      state = VerificationSubmitState(errorMessage: '인증 제출 중 오류가 발생했습니다.');
      return null;
    }
  }

  void reset() {
    state = const VerificationSubmitState();
  }

  String _extractErrorMessage(DioException e) {
    try {
      final error = e.response?.data?['error'];
      if (error != null) {
        final code = error['code'] as String?;
        switch (code) {
          case 'ALREADY_VERIFIED_TODAY':
            return '오늘 이미 인증했습니다.';
          case 'PHOTO_REQUIRED':
            return '사진이 필요한 챌린지입니다.';
          case 'CHALLENGE_ENDED':
            return '이미 종료된 챌린지입니다.';
          case 'NOT_A_MEMBER':
            return '챌린지 참여자가 아닙니다.';
          default:
            return error['message'] as String? ?? '인증 제출에 실패했습니다.';
        }
      }
    } catch (_) {}
    return '인증 제출에 실패했습니다.';
  }
}

final verificationSubmitProvider = StateNotifierProvider.family<
    VerificationSubmitNotifier, VerificationSubmitState, String>(
  (ref, challengeId) {
    final dio = ref.watch(dioProvider);
    return VerificationSubmitNotifier(dio, challengeId);
  },
);
