---
Date: 2026-04-21
Worktree (수행): feature
Worktree (영향): feature
Role: feature
---

# Miniroom Slot Variant Painter 확장

## Request

`miniroom_scene.dart` 에 8개 슬롯(wall, floor, ceiling, window, shelf, plant, desk, rug)의 variant painter 분기를 TDD 로 구현. `mr/` prefix assetKey 추가, 기존 legacy prefix 보존.

## Root Cause / Context

`room-decoration` 슬라이스(2026-04-19)에서 8개 슬롯 API 와 시드(migration 017)가 구현됐으나, `miniroom_scene.dart` 의 painter 는 wall/floor 두 슬롯만 분기하고 나머지 6개(ceiling/window/shelf/plant/desk/rug)는 고정 픽셀 아트만 그렸다. 또한 `mr/` prefix assetKey 에 대한 매핑이 없어 시드 아이템 장착 시 변화가 없었다.

## Actions

### 수정 파일

**`app/lib/core/widgets/miniroom_scene.dart`** (360 → 583줄)

- `_wallColorFor` / `_floorColorsFor` → `miniroomSceneWallColorFor` / `miniroomSceneFloorColorsFor` 로 public 노출 (`@visibleForTesting` 주석). 기존 legacy prefix (`wall/pink`, `wall/blue` 등) **보존**.
- `mr/wall_lavender` (`Color(0xFFE1D5F5)`) / `mr/wall_mint` (`Color(0xFFC8EBD6)`) 매핑 추가.
- `mr/floor_wood` / `mr/floor_tile` 매핑 추가.
- 6개 신규 variant helper 함수 추가:
  - `miniroomSceneCeilingVariantFor` — white(기본) / stars
  - `miniroomSceneWindowVariantFor` — wood(기본) / arch
  - `miniroomSceneShelfVariantFor` — wood(기본) / white
  - `miniroomScenePlantVariantFor` — cactus(기본) / monstera
  - `miniroomSceneDeskVariantFor` — wood(기본) / glass
  - `miniroomSceneRugVariantFor` — check(기본) / stripe
- `_MiniroomBackgroundPainter` 생성자에 6개 variant 파라미터 추가. 각 `_drawXxx` 에 `switch(variant)` 분기. 기본 case 는 기존 로직 그대로 복사.
- `_MiniroomForegroundPainter` 생성자에 `deskVariant` 추가. `_drawDeskFront` 팔레트 분기.
- `shouldRepaint` 에 신규 variant 필드 비교 추가.
- `withOpacity` → `withValues(alpha:)` 로 deprecation 해결.
- `MiniroomColors` 에 신규 색상 상수 추가: `wallLavender`, `wallMint`, `shelfWhiteLight`, `shelfWhiteDark`, `ceilingStar`.

**`app/test/core/widgets/miniroom_scene_test.dart`** (신규, 186줄)

- 8개 helper 함수 × (null / seed assetKey 2개 / unknown) 케이스 = 36개 테스트

### `MiniroomScene.build()` 변경

equip 에서 모든 슬롯 variant key 추출 후 BackgroundPainter / ForegroundPainter 에 주입.

## Verification

### TDD Cycle Evidence

**RED** (`flutter test test/core/widgets/miniroom_scene_test.dart` — before implementation):
```
test/core/widgets/miniroom_scene_test.dart:7:3: Error: Method not found: 'miniroomSceneWallColorFor'.
test/core/widgets/miniroom_scene_test.dart:104:14: Error: Method not found: 'miniroomSceneCeilingVariantFor'.
... (all 7 new functions missing)
00:00 +0 -1: Some tests failed.
```

**GREEN** (`flutter test test/core/widgets/miniroom_scene_test.dart` — after implementation):
```
00:00 +36: All tests passed!
```

**Full suite** (`flutter test`):
```
00:04 +134 -2: Some tests failed.
```
- 134 passed (36 new + 98 pre-existing), 2 failed — pre-existing `profile_setup_screen_test` compilation failure (documented in 2026-04-20-feature-miniroom-cyworld-wiring.md, base `dc40541`). 이번 변경과 무관.

**`flutter analyze lib/core/widgets/miniroom_scene.dart`**:
```
No issues found! (ran in 1.6s)
```

**`flutter build ios --simulator`**:
```
Xcode build done.                                            8.7s
✓ Built build/ios/iphonesimulator/Runner.app
```

**파일 크기**: 583줄 (600줄 권장 이내, 800줄 초과 금지 준수).

## Referenced Reports

- `docs/reports/2026-04-19-feature-room-decoration.md` — 부모 slice. migration 017 시드 assetKeys (`mr/...`) 출처. wall/floor phase 2 분기 최초 구현.
- `docs/reports/2026-04-20-feature-miniroom-cyworld-wiring.md` — equip wiring 증명. `my_room_screen_equip_wiring_test` 가 `wall/blue` legacy prefix 사용 — 본 slice 는 legacy prefix **보존** 확인.
- `docs/reports/2026-04-20-feature-miniroom-equip-wiring-tdd.md` — TDD 세부. `_FakeRoomEquipApi` / RED→GREEN 증거 패턴 참고.
- `docs/reports/2026-04-20-design-miniroom-cyworld-revise.md` — 디자인 컨텍스트. 슬롯 목록 및 painter 확장 방향 참고.

검색 키워드: `miniroom`, `wall_`, `floor_`, `ceiling_`, `plant_`, `desk_`, `rug_`, `shelf_`, `window_`, `miniroom_scene.dart`, `assetKey`

## Follow-ups

- 기존 `profile_setup_screen_test` (`_MockAuthNotifier.updateProfile` mock out-of-sync) 은 별도 fix 슬라이스에서 해결 필요.
- ceiling stars 픽셀은 row 0~1 위에 8개 위치로 고정. 향후 랜덤 씨드 기반으로 분산 가능.
- arch 창문 variant 에서 `wallBase` 색으로 corner clear — wall tint 변경 시 corner 색이 맞지 않을 수 있음. 향후 `wallTint` 를 `_drawWindow` 에 주입하여 개선 가능.
- iOS simulator tap-through 스모크는 `idb`/`applesimutils` 설치 후 수동 확인 권장.

## Retrospective

### What worked

- **switch 분기 패턴**: 기존 `_drawXxx` 바디를 default case 에 그대로 복사하고 신규 variant 만 새 case 로 추가하는 방식이 회귀 없는 확장을 보장했다.
- **public helper 분리**: `_xxxFor` → `miniroomSceneXxxFor` 로 이름 바꿔 top-level 함수로 두는 것이 TDD 에 가장 적합하고 side-effect 없다.
- **shouldRepaint 갱신**: 신규 variant 필드를 비교 목록에 추가해 setState 없이도 Painter 가 올바르게 재그림한다.

### What could improve

- 슬롯이 더 늘어나면 BackgroundPainter 생성자 파라미터가 계속 늘어남. `MiniroomVariants` data class 로 묶으면 가독성 + shouldRepaint 관리가 쉬워진다.
- withOpacity deprecation 은 pre-existing 이었으나 이번 파일 편집 시 함께 해결했다. 다른 파일의 동일 패턴도 별도 cleanup pass 권장.

### Process signal

- RED→GREEN 사이클이 helper 함수 API 설계 오류를 빠르게 잡아줬다 (함수명 오타 등). 테스트 작성이 인터페이스 설계를 명확히 했다.
