import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/api/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../models/auth_models.dart';

part 'auth_provider.g.dart';

@riverpod
TokenStorage tokenStorage(TokenStorageRef ref) {
  return const TokenStorage(FlutterSecureStorage());
}

@riverpod
class AuthState extends _$AuthState {
  @override
  AsyncValue<AuthUser?> build() {
    return const AsyncData(null);
  }

  /// 앱 시작 시 저장된 토큰 확인
  Future<void> checkAuthOnStartup() async {
    final storage = ref.read(tokenStorageProvider);
    final token = await storage.getAccessToken();
    if (token == null) {
      state = const AsyncData(null);
    }
    // 토큰이 있으면 state를 변경하지 않음 — splash screen이 /my-page로 이동
  }

  /// 카카오 액세스 토큰으로 서버 로그인
  Future<AuthUser> loginWithKakao(String kakaoAccessToken) async {
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/auth/kakao',
        data: {'kakao_access_token': kakaoAccessToken},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      // ResponseInterceptor가 data 필드를 추출한 후의 값
      final loginData = AuthLoginData.fromJson(
        response.data as Map<String, dynamic>,
      );
      final storage = ref.read(tokenStorageProvider);
      await storage.saveTokens(
        accessToken: loginData.accessToken,
        refreshToken: loginData.refreshToken,
      );
      state = AsyncData(loginData.user);
      return loginData.user;
    } on DioException catch (e, st) {
      state = AsyncError(e.error ?? e, st);
      rethrow;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// 프로필 업데이트 (닉네임 + 선택적 이미지)
  Future<void> updateProfile({
    required String nickname,
    XFile? profileImage,
  }) async {
    try {
      final storage = ref.read(tokenStorageProvider);
      final token = await storage.getAccessToken();
      final dio = ref.read(dioProvider);

      final formData = FormData.fromMap({
        'nickname': nickname,
        if (profileImage != null)
          'profile_image': await MultipartFile.fromFile(
            profileImage.path,
            filename: profileImage.name,
          ),
      });

      final response = await dio.put(
        '/auth/profile',
        data: formData,
        options: Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      final updateData = ProfileUpdateData.fromJson(
        response.data as Map<String, dynamic>,
      );

      // 현재 user 상태 업데이트
      final currentUser = state.valueOrNull;
      if (currentUser != null) {
        state = AsyncData(
          currentUser.copyWith(
            nickname: updateData.nickname,
            profileImageUrl: updateData.profileImageUrl,
          ),
        );
      }
    } on DioException catch (e, st) {
      state = AsyncError(e.error ?? e, st);
      rethrow;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// 개발 환경 전용: Kakao OAuth 없이 테스트 계정으로 로그인
  Future<AuthUser> devLogin({int userIndex = 1}) async {
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/auth/dev-login',
        data: {'user_index': userIndex},
      );
      final loginData = AuthLoginData.fromJson(
        response.data as Map<String, dynamic>,
      );
      final storage = ref.read(tokenStorageProvider);
      await storage.saveTokens(
        accessToken: loginData.accessToken,
        refreshToken: loginData.refreshToken,
      );
      state = AsyncData(loginData.user);
      return loginData.user;
    } on DioException catch (e, st) {
      state = AsyncError(e.error ?? e, st);
      rethrow;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// 로그아웃 — 토큰 삭제 및 상태 초기화
  Future<void> logout() async {
    final storage = ref.read(tokenStorageProvider);
    await storage.clearTokens();
    state = const AsyncData(null);
  }
}
