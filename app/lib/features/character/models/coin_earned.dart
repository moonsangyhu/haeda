import 'package:freezed_annotation/freezed_annotation.dart';

part 'coin_earned.freezed.dart';
part 'coin_earned.g.dart';

/// 인증 완료 후 획득한 코인 항목.
/// VerificationCreateResult 의 coins_earned[] 아이템.
@freezed
class CoinEarned with _$CoinEarned {
  const factory CoinEarned({
    required String type,
    required int amount,
  }) = _CoinEarned;

  factory CoinEarned.fromJson(Map<String, dynamic> json) =>
      _$CoinEarnedFromJson(json);
}

/// CoinEarned.type 에 대한 한국어 레이블.
extension CoinEarnedLabel on CoinEarned {
  String get label {
    switch (type) {
      case 'VERIFICATION':
        return '인증 완료';
      case 'STREAK_3':
        return '3일 연속!';
      case 'STREAK_7':
        return '7일 연속!';
      case 'ALL_COMPLETED':
        return '전원 달성!';
      default:
        return type;
    }
  }
}
