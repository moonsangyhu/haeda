import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/character_data.dart';
import '../models/item_data.dart';

/// GET /me/character — 내 캐릭터 장착 현황 조회.
final myCharacterProvider = FutureProvider<CharacterData>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/me/character');
  final data = response.data as Map<String, dynamic>;
  return CharacterData.fromJson(data);
});

/// GET /me/items — 내가 보유한 아이템 목록 조회.
final myItemsProvider = FutureProvider<List<UserItem>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/me/items');
  final data = response.data as List<dynamic>;
  return data
      .map((e) => UserItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// GET /users/{userId}/character — 특정 유저의 캐릭터 조회.
final userCharacterProvider =
    FutureProvider.family<CharacterData, String>((ref, userId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/users/$userId/character');
  final data = response.data as Map<String, dynamic>;
  return CharacterData.fromJson(data);
});

/// 캐릭터 장착 변경 상태.
class CharacterUpdateState {
  final bool isLoading;
  final String? errorMessage;
  final bool success;

  const CharacterUpdateState({
    this.isLoading = false,
    this.errorMessage,
    this.success = false,
  });

  CharacterUpdateState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? success,
  }) {
    return CharacterUpdateState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      success: success ?? this.success,
    );
  }
}

class CharacterUpdateNotifier extends StateNotifier<CharacterUpdateState> {
  final Dio _dio;
  final Ref _ref;

  CharacterUpdateNotifier(this._dio, this._ref)
      : super(const CharacterUpdateState());

  /// PUT /me/character — 캐릭터 슬롯 업데이트.
  /// slot: 'hat' | 'top' | 'bottom' | 'shoes' | 'accessory'
  /// itemId: null이면 해당 슬롯 해제.
  Future<bool> updateSlot(String slot, String? itemId) async {
    state = const CharacterUpdateState(isLoading: true);

    try {
      await _dio.put('/me/character', data: {slot: itemId});
      state = const CharacterUpdateState(success: true);
      _ref.invalidate(myCharacterProvider);
      return true;
    } on DioException catch (e) {
      final message = _extractMessage(e);
      state = CharacterUpdateState(errorMessage: message);
      return false;
    } catch (_) {
      state = const CharacterUpdateState(errorMessage: '캐릭터 변경 중 오류가 발생했어요.');
      return false;
    }
  }

  void reset() {
    state = const CharacterUpdateState();
  }

  String _extractMessage(DioException e) {
    try {
      final error =
          (e.response?.data as Map<String, dynamic>?)?['error']
              as Map<String, dynamic>?;
      return error?['message'] as String? ?? '캐릭터 변경에 실패했어요.';
    } catch (_) {
      return '캐릭터 변경에 실패했어요.';
    }
  }
}

final characterUpdateProvider =
    StateNotifierProvider<CharacterUpdateNotifier, CharacterUpdateState>((ref) {
  final dio = ref.watch(dioProvider);
  return CharacterUpdateNotifier(dio, ref);
});
