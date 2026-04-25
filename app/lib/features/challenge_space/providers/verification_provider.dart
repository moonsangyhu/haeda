import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/time.dart';
import '../models/verification_data.dart';
import '../providers/challenge_detail_provider.dart';

/// GET /verifications/{id} — 인증 상세 조회
final verificationDetailProvider =
    FutureProvider.family<VerificationDetail, String>(
  (ref, verificationId) async {
    final dio = ref.watch(dioProvider);
    final response = await dio.get('/verifications/$verificationId');
    final data = response.data as Map<String, dynamic>;
    return VerificationDetail.fromJson(data);
  },
);

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
  final Ref _ref;
  final String challengeId;

  VerificationSubmitNotifier(this._dio, this._ref, this.challengeId)
      : super(const VerificationSubmitState());

  /// Formats a DateTime as YYYY-MM-DD.
  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<VerificationCreateResult?> submit({
    required String diaryText,
    List<({List<int> bytes, String fileName})> photos = const [],
    String? date,
  }) async {
    state = const VerificationSubmitState(isLoading: true);

    try {
      // Compute effective date using user's day_cutoff_hour when no explicit
      // date is provided by the caller (e.g. calendar tap supplies a date).
      final effectiveDate = date ?? _computeEffectiveDate();

      final formData = FormData.fromMap({
        'diary_text': diaryText,
        'date': effectiveDate,
      });
      for (final photo in photos) {
        formData.files.add(MapEntry(
          'photos',
          MultipartFile.fromBytes(photo.bytes, filename: photo.fileName),
        ));
      }

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

  String _computeEffectiveDate() {
    final detail =
        _ref.read(challengeDetailProvider(challengeId)).valueOrNull;
    final cutoff = detail?.dayCutoffHour ?? 0;
    final today = effectiveToday(DateTime.now(), cutoff);
    return _formatDate(today);
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
          case 'ALREADY_VERIFIED':
            return '해당 날짜에 이미 인증했습니다.';
          case 'PHOTO_REQUIRED':
            return '사진이 필요한 챌린지입니다.';
          case 'CHALLENGE_ENDED':
            return '이미 종료된 챌린지입니다.';
          case 'INVALID_DATE':
            return '인증 가능한 날짜가 아닙니다.';
          case 'INVALID_DAY_CUTOFF_HOUR':
            return '올바르지 않은 경계 시각입니다.';
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
    return VerificationSubmitNotifier(dio, ref, challengeId);
  },
);
