import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/item_data.dart';
import 'coin_provider.dart';

/// GET /shop/items?category={category} — 상점 아이템 목록 조회.
/// category가 null이면 전체 목록.
final shopItemsProvider =
    FutureProvider.family<List<ShopItem>, String?>((ref, category) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(
    '/shop/items',
    queryParameters: category != null ? {'category': category} : null,
  );
  final data = response.data as List<dynamic>;
  return data
      .map((e) => ShopItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// 아이템 구매 상태.
class PurchaseState {
  final bool isLoading;
  final String? errorCode;
  final String? errorMessage;
  final bool success;

  const PurchaseState({
    this.isLoading = false,
    this.errorCode,
    this.errorMessage,
    this.success = false,
  });

  PurchaseState copyWith({
    bool? isLoading,
    String? errorCode,
    String? errorMessage,
    bool? success,
  }) {
    return PurchaseState(
      isLoading: isLoading ?? this.isLoading,
      errorCode: errorCode,
      errorMessage: errorMessage,
      success: success ?? this.success,
    );
  }
}

class ShopPurchaseNotifier extends StateNotifier<PurchaseState> {
  final Dio _dio;
  final Ref _ref;

  ShopPurchaseNotifier(this._dio, this._ref) : super(const PurchaseState());

  Future<bool> purchaseItem(String itemId) async {
    state = const PurchaseState(isLoading: true);

    try {
      await _dio.post('/shop/items/$itemId/purchase');
      state = const PurchaseState(success: true);
      // 잔액 및 내 아이템 갱신
      _ref.invalidate(coinBalanceProvider);
      _ref.invalidate(shopItemsProvider(null));
      return true;
    } on DioException catch (e) {
      final apiError = e.response?.data;
      String? code;
      String? message;
      if (apiError is Map<String, dynamic>) {
        final error = apiError['error'] as Map<String, dynamic>?;
        code = error?['code'] as String?;
        message = error?['message'] as String?;
      }
      state = PurchaseState(errorCode: code, errorMessage: message);
      return false;
    } catch (_) {
      state = const PurchaseState(errorMessage: '구매 중 오류가 발생했어요.');
      return false;
    }
  }

  void reset() {
    state = const PurchaseState();
  }
}

final shopPurchaseProvider =
    StateNotifierProvider<ShopPurchaseNotifier, PurchaseState>((ref) {
  final dio = ref.watch(dioProvider);
  return ShopPurchaseNotifier(dio, ref);
});
