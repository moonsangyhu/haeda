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
  skinTone: 'fair',
  eyeStyle: 'round',
  hairStyle: 'short',
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

/// 내 캐릭터 장착 현황 — 로컬 상태로 착용/해제 즉시 반영.
final myCharacterProvider =
    StateNotifierProvider<MyCharacterNotifier, AsyncValue<CharacterData>>(
        (ref) {
  final dio = ref.watch(dioProvider);
  return MyCharacterNotifier(dio, ref);
});

class MyCharacterNotifier extends StateNotifier<AsyncValue<CharacterData>> {
  final Dio _dio;
  final Ref _ref;

  MyCharacterNotifier(this._dio, this._ref)
      : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await _dio.get('/me/character');
      final data = response.data as Map<String, dynamic>;
      state = AsyncValue.data(CharacterData.fromJson(data));
    } catch (_) {
      state = const AsyncValue.data(_mockCharacter);
    }
  }

  /// 슬롯 착용/해제. itemId == null이면 해제.
  Future<bool> updateSlot(String slot, String? itemId) async {
    final current = state.valueOrNull;
    if (current == null) return false;

    CharacterSlot? newSlot;
    if (itemId != null) {
      final items = _ref.read(myItemsProvider).valueOrNull ?? [];
      final userItem =
          items.where((ui) => ui.item.id == itemId).firstOrNull;
      if (userItem != null) {
        newSlot = CharacterSlot(
          id: userItem.item.id,
          name: userItem.item.name,
          assetKey: userItem.item.assetKey,
          rarity: userItem.item.rarity,
        );
      }
    }

    final updated = _applySlot(current, slot, newSlot);
    state = AsyncValue.data(updated);

    // API 호출 (백엔드 있으면 동기화, 없으면 무시)
    try {
      await _dio.put('/me/character', data: {slot: itemId});
    } catch (_) {
      // 로컬 상태는 이미 반영됨
    }

    return true;
  }

  /// 외형 커스터마이징 저장.
  Future<void> saveAppearance({
    required String skinTone,
    required String eyeStyle,
    required String hairStyle,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = current.copyWith(
      skinTone: skinTone,
      eyeStyle: eyeStyle,
      hairStyle: hairStyle,
    );
    state = AsyncValue.data(updated);

    try {
      await _dio.put('/me/character/appearance', data: {
        'skin_tone': skinTone,
        'eye_style': eyeStyle,
        'hair_style': hairStyle,
      });
    } catch (_) {
      // 로컬 상태는 이미 반영됨
    }
  }

  CharacterData _applySlot(CharacterData c, String slot, CharacterSlot? s) {
    switch (slot) {
      case 'hat':
        return c.copyWith(hat: s);
      case 'top':
        return c.copyWith(top: s);
      case 'bottom':
        return c.copyWith(bottom: s);
      case 'shoes':
        return c.copyWith(shoes: s);
      case 'accessory':
        return c.copyWith(accessory: s);
      default:
        return c;
    }
  }
}

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

