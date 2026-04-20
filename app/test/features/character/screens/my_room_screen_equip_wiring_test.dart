import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haeda/core/api/api_client.dart';
import 'package:haeda/core/widgets/miniroom_scene.dart';
import 'package:haeda/features/character/models/item_data.dart';
import 'package:haeda/features/character/screens/my_room_screen.dart';
import 'package:haeda/features/room_decoration/api/room_equip_api.dart';
import 'package:haeda/features/room_decoration/models/room_equip.dart';
import 'package:haeda/features/room_decoration/models/room_slot.dart';
import 'package:haeda/features/room_decoration/providers/room_equip_provider.dart';

// ─── Fake RoomEquipApi — returns a fixed MiniroomEquip without any network call ───

class _FakeRoomEquipApi implements RoomEquipApi {
  final MiniroomEquip _equip;
  const _FakeRoomEquipApi(this._equip);

  @override
  Future<MiniroomEquip> getMiniroom() async => _equip;

  @override
  Future<MiniroomEquip> updateMiniroom(Map<MiniroomSlot, String?> changes) async => _equip;

  @override
  Future<void> clearMiniroomSlot(MiniroomSlot slot) async {}

  @override
  Future<List<UserItem>> getMyItemsByCategory(String category) async => [];

  @override
  Future<List<ShopItem>> getShopItemsByCategory(String category) async => [];
}

// ─── Fake Dio — all requests fail immediately so MyCharacterNotifier falls back to _mockCharacter ───

Dio _buildFakeDio() {
  return Dio(BaseOptions(
    baseUrl: 'http://127.0.0.1:1',
    connectTimeout: const Duration(milliseconds: 1),
    receiveTimeout: const Duration(milliseconds: 1),
  ));
}

// ─── Helper: pump MyRoomScreen with given equip state ───

Future<void> _pumpMyRoomScreen(
  WidgetTester tester,
  MiniroomEquip equip,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(_buildFakeDio()),
        myMiniroomProvider.overrideWith(
          (ref) => MyMiniroomNotifier(_FakeRoomEquipApi(equip)),
        ),
      ],
      child: const MaterialApp(
        home: MyRoomScreen(),
      ),
    ),
  );
  // Let async state settle (fake API resolves in a microtask)
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('MyRoomScreen equip wiring', () {
    testWidgets('wiring test: MiniroomScene receives equip from myMiniroomProvider', (tester) async {
      const equip = MiniroomEquip(
        wall: EquippedItemBrief(
          id: 't1',
          name: 'Blue Wall',
          category: 'mr.wall',
          rarity: 'COMMON',
          assetKey: 'wall/blue',
        ),
      );

      await _pumpMyRoomScreen(tester, equip);

      final scene = tester.widget<MiniroomScene>(find.byType(MiniroomScene));
      expect(
        scene.equip?.wall?.assetKey,
        equals('wall/blue'),
        reason: 'MiniroomScene.equip should be wired from myMiniroomProvider',
      );
    });

    testWidgets('regression test: MiniroomScene with empty equip has null wall and floor', (tester) async {
      final equip = MiniroomEquip.empty();

      await _pumpMyRoomScreen(tester, equip);

      final scene = tester.widget<MiniroomScene>(find.byType(MiniroomScene));
      expect(scene.equip?.wall, isNull,
          reason: 'empty equip should have null wall');
      expect(scene.equip?.floor, isNull,
          reason: 'empty equip should have null floor');
    });
  });
}
