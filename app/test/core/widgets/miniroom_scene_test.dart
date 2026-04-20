import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:haeda/core/widgets/miniroom_scene.dart';

void main() {
  group('miniroomSceneWallColorFor', () {
    test('returns null for null assetKey', () {
      expect(miniroomSceneWallColorFor(null), isNull);
    });

    test('legacy wall/pink returns pink tone', () {
      final c = miniroomSceneWallColorFor('wall/pink');
      expect(c, isNotNull);
      expect(c, equals(const Color(0xFFFFB3C1)));
    });

    test('legacy wall/blue returns blue tone', () {
      final c = miniroomSceneWallColorFor('wall/blue');
      expect(c, isNotNull);
      expect(c, equals(const Color(0xFFB3D9FF)));
    });

    test('mr/wall_lavender returns lavender tone', () {
      final c = miniroomSceneWallColorFor('mr/wall_lavender');
      expect(c, isNotNull);
      expect(c, equals(const Color(0xFFE1D5F5)));
    });

    test('mr/wall_mint returns mint tone', () {
      final c = miniroomSceneWallColorFor('mr/wall_mint');
      expect(c, isNotNull);
      expect(c, equals(const Color(0xFFC8EBD6)));
    });

    test('unknown key returns fallback (non-null)', () {
      final c = miniroomSceneWallColorFor('unknown/xyz');
      expect(c, isNotNull);
    });
  });

  group('miniroomSceneFloorColorsFor', () {
    test('returns null for null assetKey', () {
      expect(miniroomSceneFloorColorsFor(null), isNull);
    });

    test('legacy floor/wood returns wood colors', () {
      final c = miniroomSceneFloorColorsFor('floor/wood');
      expect(c, isNotNull);
      expect(c!.length, 2);
      expect(c[0], equals(const Color(0xFFD4A574)));
    });

    test('legacy floor/tile returns tile colors', () {
      final c = miniroomSceneFloorColorsFor('floor/tile');
      expect(c, isNotNull);
      expect(c!.length, 2);
    });

    test('mr/floor_wood returns wood colors', () {
      final c = miniroomSceneFloorColorsFor('mr/floor_wood');
      expect(c, isNotNull);
      expect(c!.length, 2);
      expect(c[0], equals(const Color(0xFFD4A574)));
    });

    test('mr/floor_tile returns tile colors', () {
      final c = miniroomSceneFloorColorsFor('mr/floor_tile');
      expect(c, isNotNull);
      expect(c!.length, 2);
      expect(c[0], equals(const Color(0xFFE0E0E0)));
    });

    test('unknown key returns null', () {
      expect(miniroomSceneFloorColorsFor('unknown/abc'), isNull);
    });
  });

  group('miniroomSceneCeilingVariantFor', () {
    test('null returns default', () {
      expect(miniroomSceneCeilingVariantFor(null), equals('white'));
    });

    test('mr/ceiling_white returns white', () {
      expect(miniroomSceneCeilingVariantFor('mr/ceiling_white'), equals('white'));
    });

    test('mr/ceiling_stars returns stars', () {
      expect(miniroomSceneCeilingVariantFor('mr/ceiling_stars'), equals('stars'));
    });

    test('unknown returns default', () {
      expect(miniroomSceneCeilingVariantFor('unknown'), equals('white'));
    });
  });

  group('miniroomSceneWindowVariantFor', () {
    test('null returns wood', () {
      expect(miniroomSceneWindowVariantFor(null), equals('wood'));
    });

    test('mr/window_wood returns wood', () {
      expect(miniroomSceneWindowVariantFor('mr/window_wood'), equals('wood'));
    });

    test('mr/window_arch returns arch', () {
      expect(miniroomSceneWindowVariantFor('mr/window_arch'), equals('arch'));
    });

    test('unknown returns wood', () {
      expect(miniroomSceneWindowVariantFor('unknown'), equals('wood'));
    });
  });

  group('miniroomSceneShelfVariantFor', () {
    test('null returns wood', () {
      expect(miniroomSceneShelfVariantFor(null), equals('wood'));
    });

    test('mr/shelf_wood returns wood', () {
      expect(miniroomSceneShelfVariantFor('mr/shelf_wood'), equals('wood'));
    });

    test('mr/shelf_white returns white', () {
      expect(miniroomSceneShelfVariantFor('mr/shelf_white'), equals('white'));
    });

    test('unknown returns wood', () {
      expect(miniroomSceneShelfVariantFor('unknown'), equals('wood'));
    });
  });

  group('miniroomScenePlantVariantFor', () {
    test('null returns cactus', () {
      expect(miniroomScenePlantVariantFor(null), equals('cactus'));
    });

    test('mr/plant_cactus returns cactus', () {
      expect(miniroomScenePlantVariantFor('mr/plant_cactus'), equals('cactus'));
    });

    test('mr/plant_monstera returns monstera', () {
      expect(miniroomScenePlantVariantFor('mr/plant_monstera'), equals('monstera'));
    });

    test('unknown returns cactus', () {
      expect(miniroomScenePlantVariantFor('unknown'), equals('cactus'));
    });
  });

  group('miniroomSceneDeskVariantFor', () {
    test('null returns wood', () {
      expect(miniroomSceneDeskVariantFor(null), equals('wood'));
    });

    test('mr/desk_wood returns wood', () {
      expect(miniroomSceneDeskVariantFor('mr/desk_wood'), equals('wood'));
    });

    test('mr/desk_glass returns glass', () {
      expect(miniroomSceneDeskVariantFor('mr/desk_glass'), equals('glass'));
    });

    test('unknown returns wood', () {
      expect(miniroomSceneDeskVariantFor('unknown'), equals('wood'));
    });
  });

  group('miniroomSceneRugVariantFor', () {
    test('null returns check', () {
      expect(miniroomSceneRugVariantFor(null), equals('check'));
    });

    test('mr/rug_check returns check', () {
      expect(miniroomSceneRugVariantFor('mr/rug_check'), equals('check'));
    });

    test('mr/rug_stripe returns stripe', () {
      expect(miniroomSceneRugVariantFor('mr/rug_stripe'), equals('stripe'));
    });

    test('unknown returns check', () {
      expect(miniroomSceneRugVariantFor('unknown'), equals('check'));
    });
  });
}
