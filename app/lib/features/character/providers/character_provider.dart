import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/character_data.dart';
import '../models/item_data.dart';

/// 테스트용 목 캐릭터 — 분홍 비니 + 체크셔츠 + 청바지 + 운동화 + 선글라스.
const _mockCharacter = CharacterData(
  hat: CharacterSlot(
    id: 'mock-hat',
    name: '분홍 비니',
    assetKey: 'hat/pink_beanie.png',
    rarity: 'COMMON',
  ),
  top: CharacterSlot(
    id: 'mock-top',
    name: '체크무늬 셔츠',
    assetKey: 'top/check_shirt.png',
    rarity: 'RARE',
  ),
  bottom: CharacterSlot(
    id: 'mock-bottom',
    name: '청바지',
    assetKey: 'bottom/jeans.png',
    rarity: 'COMMON',
  ),
  shoes: CharacterSlot(
    id: 'mock-shoes',
    name: '운동화',
    assetKey: 'shoes/sneakers.png',
    rarity: 'COMMON',
  ),
  accessory: CharacterSlot(
    id: 'mock-acc',
    name: '선글라스',
    assetKey: 'accessory/sunglasses.png',
    rarity: 'RARE',
  ),
);

/// 테스트용 목 보유 아이템 — 카테고리별 여러 개.
final _mockItems = <UserItem>[
  // ── HAT ──
  const UserItem(
    id: 'ui-1',
    item: ShopItem(id: 'mock-hat', name: '분홍 비니', category: 'HAT', price: 40, rarity: 'COMMON', assetKey: 'hat/pink_beanie.png'),
    purchasedAt: '2026-04-10T00:00:00Z',
  ),
  const UserItem(
    id: 'ui-1b',
    item: ShopItem(id: 'mock-hat-cap', name: '캡모자', category: 'HAT', price: 30, rarity: 'COMMON', assetKey: 'hat/cap.png'),
    purchasedAt: '2026-04-09T00:00:00Z',
  ),
  const UserItem(
    id: 'ui-1c',
    item: ShopItem(id: 'mock-hat-fedora', name: '페도라', category: 'HAT', price: 120, rarity: 'RARE', assetKey: 'hat/fedora.png', effectType: 'COIN_BOOST', effectValue: 10),
    purchasedAt: '2026-04-08T00:00:00Z',
  ),
  const UserItem(
    id: 'ui-1d',
    item: ShopItem(id: 'mock-hat-crown', name: '왕관', category: 'HAT', price: 400, rarity: 'EPIC', assetKey: 'hat/crown.png', effectType: 'STREAK_SHIELD', effectValue: 3),
    purchasedAt: '2026-04-07T00:00:00Z',
  ),
  // ── TOP ──
  const UserItem(
    id: 'ui-2',
    item: ShopItem(id: 'mock-top', name: '체크무늬 셔츠', category: 'TOP', price: 120, rarity: 'RARE', assetKey: 'top/check_shirt.png', effectType: 'COIN_BOOST', effectValue: 10),
    purchasedAt: '2026-04-10T00:00:00Z',
  ),
  const UserItem(
    id: 'ui-2b',
    item: ShopItem(id: 'mock-top-hoodie', name: '후드티', category: 'TOP', price: 120, rarity: 'RARE', assetKey: 'top/hoodie.png', effectType: 'VERIFY_BONUS', effectValue: 3),
    purchasedAt: '2026-04-09T00:00:00Z',
  ),
  const UserItem(
    id: 'ui-2c',
    item: ShopItem(id: 'mock-top-tux', name: '턱시도', category: 'TOP', price: 400, rarity: 'EPIC', assetKey: 'top/tuxedo.png', effectType: 'COIN_BOOST', effectValue: 30),
    purchasedAt: '2026-04-08T00:00:00Z',
  ),
  // ── BOTTOM ──
  const UserItem(
    id: 'ui-3',
    item: ShopItem(id: 'mock-bottom', name: '청바지', category: 'BOTTOM', price: 30, rarity: 'COMMON', assetKey: 'bottom/jeans.png'),
    purchasedAt: '2026-04-10T00:00:00Z',
  ),
  const UserItem(
    id: 'ui-3b',
    item: ShopItem(id: 'mock-bottom-skirt', name: '치마', category: 'BOTTOM', price: 120, rarity: 'RARE', assetKey: 'bottom/skirt.png', effectType: 'VERIFY_BONUS', effectValue: 3),
    purchasedAt: '2026-04-09T00:00:00Z',
  ),
  // ── SHOES ──
  const UserItem(
    id: 'ui-4',
    item: ShopItem(id: 'mock-shoes', name: '운동화', category: 'SHOES', price: 40, rarity: 'COMMON', assetKey: 'shoes/sneakers.png'),
    purchasedAt: '2026-04-10T00:00:00Z',
  ),
  const UserItem(
    id: 'ui-4b',
    item: ShopItem(id: 'mock-shoes-boots', name: '부츠', category: 'SHOES', price: 120, rarity: 'RARE', assetKey: 'shoes/boots.png', effectType: 'STREAK_SHIELD', effectValue: 1),
    purchasedAt: '2026-04-09T00:00:00Z',
  ),
  // ── ACCESSORY ──
  const UserItem(
    id: 'ui-5',
    item: ShopItem(id: 'mock-acc', name: '선글라스', category: 'ACCESSORY', price: 120, rarity: 'RARE', assetKey: 'accessory/sunglasses.png', effectType: 'COIN_BOOST', effectValue: 10),
    purchasedAt: '2026-04-10T00:00:00Z',
  ),
  const UserItem(
    id: 'ui-5b',
    item: ShopItem(id: 'mock-acc-wings', name: '천사날개', category: 'ACCESSORY', price: 400, rarity: 'EPIC', assetKey: 'accessory/angel_wings.png', effectType: 'COIN_BOOST', effectValue: 25),
    purchasedAt: '2026-04-08T00:00:00Z',
  ),
];

/// GET /me/character — 내 캐릭터 장착 현황 조회.
/// API 실패 시 테스트용 목 데이터 반환.
final myCharacterProvider = FutureProvider<CharacterData>((ref) async {
  try {
    final dio = ref.watch(dioProvider);
    final response = await dio.get('/me/character');
    final data = response.data as Map<String, dynamic>;
    return CharacterData.fromJson(data);
  } catch (_) {
    return _mockCharacter;
  }
});

/// GET /me/items — 내가 보유한 아이템 목록 조회.
/// API 실패 시 테스트용 목 데이터 반환.
final myItemsProvider = FutureProvider<List<UserItem>>((ref) async {
  try {
    final dio = ref.watch(dioProvider);
    final response = await dio.get('/me/items');
    final data = response.data as List<dynamic>;
    return data
        .map((e) => UserItem.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return _mockItems;
  }
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
