import 'package:freezed_annotation/freezed_annotation.dart';

part 'coin_data.freezed.dart';
part 'coin_data.g.dart';

/// GET /me/coins 응답의 data 필드.
@freezed
class CoinBalance with _$CoinBalance {
  const factory CoinBalance({
    required int balance,
  }) = _CoinBalance;

  factory CoinBalance.fromJson(Map<String, dynamic> json) =>
      _$CoinBalanceFromJson(json);
}

/// GET /me/coins/transactions 응답의 items[] 아이템.
@freezed
class CoinTransaction with _$CoinTransaction {
  const factory CoinTransaction({
    required String id,
    required int amount,
    required String type,
    @JsonKey(name: 'reference_id') String? referenceId,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _CoinTransaction;

  factory CoinTransaction.fromJson(Map<String, dynamic> json) =>
      _$CoinTransactionFromJson(json);
}

/// GET /me/coins/transactions 응답의 data 필드.
@freezed
class CoinTransactionList with _$CoinTransactionList {
  const factory CoinTransactionList({
    required List<CoinTransaction> items,
    @JsonKey(name: 'next_cursor') String? nextCursor,
  }) = _CoinTransactionList;

  factory CoinTransactionList.fromJson(Map<String, dynamic> json) =>
      _$CoinTransactionListFromJson(json);
}
