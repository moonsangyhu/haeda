import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/comment_data.dart';

/// GET /verifications/{id} — 인증 상세 + 댓글 목록 조회
final verificationDetailProvider =
    FutureProvider.family<VerificationDetail, String>(
  (ref, verificationId) async {
    final dio = ref.watch(dioProvider);
    final response = await dio.get('/verifications/$verificationId');
    final data = response.data as Map<String, dynamic>;
    return VerificationDetail.fromJson(data['data'] as Map<String, dynamic>);
  },
);

/// 댓글 제출 상태
class CommentSubmitState {
  final bool isLoading;
  final String? errorMessage;

  const CommentSubmitState({
    this.isLoading = false,
    this.errorMessage,
  });
}

class CommentSubmitNotifier extends StateNotifier<CommentSubmitState> {
  final Dio _dio;
  final String verificationId;

  CommentSubmitNotifier(this._dio, this.verificationId)
      : super(const CommentSubmitState());

  /// POST /verifications/{id}/comments
  Future<bool> submit(String content) async {
    state = const CommentSubmitState(isLoading: true);
    try {
      await _dio.post(
        '/verifications/$verificationId/comments',
        data: {'content': content},
      );
      state = const CommentSubmitState();
      return true;
    } on DioException catch (e) {
      state = CommentSubmitState(errorMessage: _extractError(e));
      return false;
    } catch (_) {
      state = const CommentSubmitState(errorMessage: '댓글 작성 중 오류가 발생했습니다.');
      return false;
    }
  }

  void reset() {
    state = const CommentSubmitState();
  }

  String _extractError(DioException e) {
    try {
      final error = e.response?.data?['error'];
      if (error != null) {
        final code = error['code'] as String?;
        switch (code) {
          case 'NOT_A_MEMBER':
            return '챌린지 참여자가 아닙니다.';
          case 'VERIFICATION_NOT_FOUND':
            return '인증을 찾을 수 없습니다.';
          case 'COMMENT_TOO_LONG':
            return '댓글은 500자를 초과할 수 없습니다.';
          default:
            return error['message'] as String? ?? '댓글 작성에 실패했습니다.';
        }
      }
    } catch (_) {}
    return '댓글 작성에 실패했습니다.';
  }
}

final commentSubmitProvider = StateNotifierProvider.family<
    CommentSubmitNotifier, CommentSubmitState, String>(
  (ref, verificationId) =>
      CommentSubmitNotifier(ref.watch(dioProvider), verificationId),
);
