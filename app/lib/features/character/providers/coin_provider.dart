import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/coin_data.dart';

/// GET /me/coins — 현재 코인 잔액 조회.
final coinBalanceProvider = FutureProvider<CoinBalance>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/me/coins');
  final data = response.data as Map<String, dynamic>;
  return CoinBalance.fromJson(data);
});

/// GET /me/coins/transactions — 코인 거래 내역 조회.
final coinTransactionsProvider =
    FutureProvider<CoinTransactionList>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/me/coins/transactions');
  final data = response.data as Map<String, dynamic>;
  return CoinTransactionList.fromJson(data);
});
