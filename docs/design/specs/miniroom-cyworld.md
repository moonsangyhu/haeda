---
slug: miniroom-cyworld
status: in-progress
created: 2026-04-15
updated: 2026-04-20
area: front
supersedes-note: |
  2026-04-15 greenfield 가정으로 작성. 2026-04-19 에 `room_decoration`
  피처(P2 Phase 1+2)가 선행 구현되어 `MiniroomScene`·`EquipStatBar` 는
  이미 존재하고, 8-슬롯 장착 시스템(`myMiniroomProvider` /
  `MiniroomEquip`)이 가동 중이다. 본 문서는 해당 구현을 베이스로 삼아
  **재구현이 아닌 wiring 보완·painter 분기 확장**을 기술하도록 2026-04-20 개정.

  핵심 수정 이유: 원본 스펙대로 재구현하면 `miniroom_scene.dart` 의
  `equip` 파라미터와 `room_decoration` 통합이 삭제되어, 사용자가 꾸며둔
  내 방(벽/바닥 등)이 렌더되지 않고 기본 모습만 나오는 회귀가 발생한다.
---

# My Room — Cyworld Miniroom Style Redesign

## Overview

"내 방" 화면을 2000년대 싸이월드 미니룸 스타일의 픽셀아트 방으로 구성한다. 벽/바닥/가구가 있는 작은 방 안에 캐릭터가 서 있고, 방 아래에 능력치 바가 붙고, 그 아래에 카테고리별 아이템 그리드가 깔리는 레이아웃.

### 현재 구현 상태 (2026-04-20 기준)

본 스펙의 시각·레이아웃 뼈대는 이미 구현되어 있다. 따라서 이 문서는 "재구현" 이 아니라 **"이미 있는 구현 위에 남은 간극을 메우는 작업"** 을 기술한다.

| 요소 | 상태 | 경로 |
|------|------|------|
| `MiniroomScene` | 구현 완료. `MiniroomEquip? equip` 파라미터 지원. `wall/floor` assetKey 분기 painter. | `app/lib/core/widgets/miniroom_scene.dart:59` |
| `MiniroomColors` 팔레트 | 구현 완료. | `app/lib/core/widgets/miniroom_scene.dart:8` |
| `EquipStatBar` | 구현 완료. 3개 항목, 높이 36dp, 방 하단 부착. | `app/lib/features/character/widgets/equip_stat_bar.dart` |
| `MyRoomScreen` 레이아웃 | 구현 완료. MiniroomScene + EquipStatBar + TabBar + GridView. | `app/lib/features/character/screens/my_room_screen.dart` |
| 방 꾸미기 8 슬롯 시스템 | 구현 완료 (Phase 2). wall/ceiling/window/shelf/plant/desk/rug/floor. | `app/lib/features/room_decoration/` |
| `myMiniroomProvider` | 구현 완료. `MiniroomEquip` 상태 관리·낙관적 업데이트. | `app/lib/features/room_decoration/providers/room_equip_provider.dart:17` |

### 남은 간극 (본 스펙이 닫아야 하는 문제)

1. **Wiring 누락** — `my_room_screen.dart:107-112` 의 `MiniroomScene(...)` 호출부가 `equip` 을 전달하지 않는다. 그 결과 사용자가 `RoomDecoratorScreen` 에서 저장한 벽/바닥 variant 가 내 방 탭에서 렌더되지 않는다. (§Equip Integration Contract 참고)
2. **Painter 분기 미확장** — `wall` / `floor` 외 6 슬롯(ceiling, window, shelf, plant, desk, rug) 은 아직 기본 painter 고정. 본 문서는 확장 경로만 문서화하고, 실제 variant painter 는 별 slice 에서 추가.
3. **하드코딩 가구의 의미 재정의** — 원본 문서의 Grid Layout 표에 나열된 가구들은 이제 "슬롯의 기본 variant" 로 해석되어야 한다. "고정 하드코딩" 이 아님.

## Design Concept

**3/4 탑뷰 픽셀아트 방** — 뒷벽이 화면 상단에 평면으로, 바닥이 아래쪽으로 깊이감을 주는 클래식 RPG/싸이월드 스타일. 방은 풀 너비로 짤림 없이 보여주고, 능력치는 방 바로 아래 별도 영역에 표시.

```
 ┌──────────────────────────────────┐
 │  천장 몰딩                         │
 │  ┌───────┐   🕐   ┌──────────┐  │
 │  │ 창문  │        │  선반    │  │  ← 뒷벽 (유저 배경색 틴트)
 │  │ (하늘) │        │ 📚☕    │  │
 │  └───────┘        └──────────┘  │
 │══════════════════════════════════│  ← 걸레받이
 │     ┌────┐   🧍‍♂️    🌱        │
 │     │책상│  캐릭터   화분       │  ← 바닥 (체커보드)
 │     │💡 │  (탭 반응)           │
 │     └────┘    ╭────────╮       │
 │               │  러그   │       │
 │               ╰────────╯       │
 └──────────────────────────────────┘
 ┌──────────────────────────────────┐
 │ 💰 +5%    ⭐ +3    🛡️ 1회      │  ← 능력치 바 (방 아래, 한 줄 가로 배치)
 └──────────────────────────────────┘
```

## Architecture

> ⚠️ 2026-04-20 개정: 아래 항목은 모두 **이미 존재하는 파일**이다. 본 스펙은 "추가·확장" 작업을 기술한다. "신규 파일 생성" 으로 오독하지 말 것 — 재구현하면 `equip` 파라미터·room_decoration 통합이 사라진다.

### Existing Files (확장 대상)

1. **`app/lib/core/widgets/miniroom_scene.dart`** (현재 360줄, 유지·확장)
   - `MiniroomScene` — StatelessWidget, Stack 기반. `MiniroomEquip? equip` 파라미터 **이미 받음**.
   - `MiniroomColors` — 색상 상수. **유지**.
   - `_MiniroomBackgroundPainter` / `_MiniroomForegroundPainter` — 32x24 논리 그리드.
   - `_wallColorFor(assetKey)` (:140) / `_floorColorsFor(assetKey)` (:151) — 슬롯 assetKey → 색 분기. **유지 + ceiling/window/shelf/plant/desk/rug 분기 추가 (§Equip Integration Contract)**.

2. **`app/lib/features/character/widgets/equip_stat_bar.dart`** (현재 구현, 유지)
   - `EquipStatBar`, `EquipStats`, `calcEquipStats()`, `getEquippedItems()`. **변경 없음**.

### Existing Files (Wiring 수정 필수)

3. **`app/lib/features/character/screens/my_room_screen.dart`** (수정)
   - 현재 `MiniroomScene(character, wallTintColor, height, characterSize)` (`:107-112`) 호출은 `equip` 미전달 → 방 꾸미기 결과 미반영.
   - **수정 요구**: `ref.watch(myMiniroomProvider).valueOrNull` 을 `equip` 파라미터로 전달 (§Equip Integration Contract 참고).
   - 레이아웃 (Scaffold > Column > MiniroomScene > EquipStatBar > TabBar > GridView) 은 이미 본 스펙과 일치. 변경하지 않는다.

## Equip Integration Contract

`MiniroomScene` 이 존재하는 이유의 절반은 **사용자 꾸미기를 렌더** 하기 위함이다. wiring 이 끊어져 있으면 스펙을 아무리 충실히 그려도 "사용자의 내 방" 은 사라진다. 이 섹션은 재발 방지를 위한 명시적 계약이다.

### 호출부 계약 (`my_room_screen.dart`)

```dart
// ❌ 현재 (equip 미전달 — 사용자 꾸미기가 렌더되지 않는 원인)
MiniroomScene(
  character: character,
  wallTintColor: userBgColor,
  height: roomHeight,
  characterSize: charSize,
)

// ✅ 수정 후
final equip = ref.watch(myMiniroomProvider).valueOrNull;
MiniroomScene(
  character: character,
  wallTintColor: userBgColor,
  equip: equip,                     // ← 필수
  height: roomHeight,
  characterSize: charSize,
)
```

`myMiniroomProvider` 는 `room_equip_provider.dart:17` 에 정의되어 있고, `RoomDecoratorScreen` 이 편집·저장할 때 이미 이 provider 를 갱신하고 있다. 따라서 `my_room_screen` 이 watch 만 하면 실시간 반영된다.

### Slot → Painter 분기 매핑

| Slot | assetKey prefix | 현재 상태 | 확장 계획 |
|------|-----------------|---------|----------|
| `mr.wall` | `wall/{color}` | 구현됨 (`_wallColorFor`) | 유지 |
| `mr.floor` | `floor/{pattern}` | 구현됨 (`_floorColorsFor`) | 유지 |
| `mr.ceiling` | `ceiling/{kind}` | 기본 painter 고정 | 신규 `_drawCeilingVariant` — 기본 몰딩 vs 펜던트·샹들리에 |
| `mr.window` | `window/{scene}` | `_drawWindow` 기본 하늘 | `skyBlue`·풍경 swap — 하늘·노을·밤·벚꽃 |
| `mr.shelf` | `shelf/{kind}` | `_drawShelf` 기본 2단 | 책장·공중 선반 variant |
| `mr.plant` | `plant/{kind}` | `_drawPlant` 기본 화분 | 선인장·몬스테라·꽃다발 |
| `mr.desk` | `desk/{kind}` | `_drawDesk` 기본 | 게이밍·좌식 variant |
| `mr.rug` | `rug/{kind}` | `_drawRug` 원형 러그 | 별·체크·구름 variant |

**Phase 2 (현재) 현황**: wall/floor 외 6 슬롯은 사용자가 편집·저장하더라도 방 씬은 기본 variant 만 렌더한다. 이는 의도된 점진 확장이며, 본 스펙은 **매핑 계약 확정 + wiring 수정**까지만 다룬다. 각 슬롯별 variant painter 추가는 별 slice.

### 데이터 흐름

```
사용자 → RoomDecoratorScreen → 슬롯 편집·저장
  → myMiniroomProvider.updateSlots(changes)
  → PUT /me/room/miniroom
  → state = AsyncValue.data(MiniroomEquip)
  → my_room_screen rebuild (watch)
  → MiniroomScene(equip: ...) 재렌더
  → _MiniroomBackgroundPainter 가 assetKey 별 분기 → 화면에 반영
```

이 경로의 **3번째 화살표 이후가 현재 끊겨 있다**. `my_room_screen` 이 `myMiniroomProvider` 를 watch 하지 않고 `equip` 을 전달하지 않기 때문. 이것이 본 스펙의 핵심 수정 포인트.

## Grid Layout (32x24)

아래 표의 각 가구는 **슬롯의 "기본 variant"** 이다. `MiniroomEquip` 에 해당 슬롯의 아이템이 있으면 그 variant 로 대체되어 렌더된다(§Equip Integration Contract). `Clock` 과 `Baseboard`, `Back wall tint blend` 같은 **고정 장식(non-slot)** 과 구분한다.

| Element | Grid Position | Slot / 역할 | Description |
|---------|---------------|-------------|-------------|
| Ceiling molding | rows 0-1 | `mr.ceiling` 기본 variant | Decorative line |
| Back wall | rows 2-11 | `mr.wall` 기본 variant | User background color tint (30% blend). `mr.wall` 아이템 있으면 45% blend 로 대체. |
| Window | cols 3-10, rows 3-9 | `mr.window` 기본 variant | Sky blue glass + white cross-pane + cloud |
| Clock | cols 15-17, rows 3-5 | **고정 장식 (non-slot)** | Circular face, two hands — 변형 없음 |
| Shelf | cols 22-30, rows 5-8 | `mr.shelf` 기본 variant | Wood plank + books + mug |
| Baseboard | row 12 | **고정 장식** | Wall-floor edge — 변형 없음 |
| Floor | rows 12-23 | `mr.floor` 기본 variant | Checkerboard pattern (warm cream) |
| Desk | cols 1-8, rows 14-20 | `mr.desk` 기본 variant | Side view, wood, lamp on top |
| Rug | cols 10-22, rows 17-22 | `mr.rug` 기본 variant | Oval, wallTint variant |
| Plant | cols 26-29, rows 17-20 | `mr.plant` 기본 variant | Green leaves + brown pot |
| Character | center, rows 10-22 | — | Existing CharacterAvatar (110dp) |

## Color Palette

```dart
class MiniroomColors {
  // Wall
  static const wallBase = Color(0xFFFFF5F8);      // very light pink-white
  static const wallShadow = Color(0xFFFFE4EC);    // depth shadow

  // Floor
  static const floorLight = Color(0xFFFFF0E8);    // warm cream
  static const floorDark = Color(0xFFFFE0D0);     // checkerboard dark

  // Baseboard / molding
  static const baseboard = Color(0xFFE8C8D0);
  static const moldingTop = Color(0xFFF0D8E0);

  // Furniture wood
  static const woodLight = Color(0xFFD4A574);
  static const woodDark = Color(0xFFB07848);
  static const woodShadow = Color(0xFF8B6040);

  // Window
  static const windowFrame = Color(0xFFE0C8D0);
  static const windowGlass = Color(0xFFE8F4FD);   // Cyworld sky-blue homage
  static const skyBlue = Color(0xFFB3E5FC);
  static const windowPane = Color(0xFFFFFFFF);

  // Decorative
  static const rugBase = Color(0xFFF8BBD0);        // pink rug
  static const rugDark = Color(0xFFF48FB1);
  static const plantGreen = Color(0xFF81C784);
  static const plantDark = Color(0xFF4CAF50);
  static const potBrown = Color(0xFFA1887F);
  static const potDark = Color(0xFF8D6E63);
  static const lampYellow = Color(0xFFFFF9C4);
  static const lampGlow = Color(0xFFFFECB3);
  static const clockFace = Color(0xFFFFFDE7);
  static const clockHand = Color(0xFF5D4037);
  static const bookSpine1 = Color(0xFFCE93D8);    // purple book
  static const bookSpine2 = Color(0xFF90CAF9);    // blue book
  static const bookSpine3 = Color(0xFFA5D6A7);    // green book
  static const mugWhite = Color(0xFFFFF8E1);

  // Room border
  static const roomBorder = Color(0xFFE0BFC7);    // matches app outline
}
```

**Wall tinting**: `Color.lerp(wallBase, userBackgroundColor, 0.3)`

## Character Integration (Stack)

MiniroomScene은 방 배경 + 캐릭터 + 전경 가구만 포함. 능력치는 방 밖(아래)에 별도 위젯으로 배치.

```dart
// MiniroomScene — 방만 풀 너비로 렌더링, statOverlay 파라미터 없음
Stack(
  children: [
    CustomPaint(painter: _MiniroomBackgroundPainter(wallTint: tint)),
    Positioned(
      left: (width - charSize) / 2,
      top: height * 0.18,
      child: TappableCharacter(
        child: CharacterAvatar(character: character, size: charSize),
      ),
    ),
    CustomPaint(painter: _MiniroomForegroundPainter()),
  ],
)
```

## Equip Stat Bar (방 아래 능력치)

방 바로 아래에 가로 한 줄로 표시하는 능력치 바. 방과 시각적으로 연결되되, 방 내부를 가리지 않음.

```dart
// MyRoomScreen layout:
Column(
  children: [
    MiniroomScene(character: character, wallTint: color, height: 250),
    EquipStatBar(stats: stats),   // ← 방 바로 아래
    TabBar(...),
    Expanded(child: GridView(...)),
  ],
)
```

**EquipStatBar 디자인:**
- 높이: 36dp
- 마진: 방과 동일 좌우 12dp (방 프레임과 폭 맞춤)
- 배경: surfaceContainerHighest.withOpacity(0.5), borderRadius 0 0 12 12 (방 프레임 아래 이어지는 느낌)
- 3개 항목을 `Row(mainAxisAlignment: spaceEvenly)`로 균등 배치:
  - `💰 코인부스트 +5%` | `⭐ 인증보너스 +3` | `🛡️ 연속실드 1회`
- 효과 없는 항목은 흐리게 (opacity 0.4)
- 전부 0이면 "효과 아이템을 착용해보세요!" 한 줄 텍스트

## UI Style Updates

- **TabBar**: 둥근 pill indicator, 파스텔 핑크 배경
- **ItemCard**: borderRadius 18, 장착 시 그라디언트 배경
- **Room frame**: 3px rounded border (borderRadius 16), subtle shadow

## Responsive

- Screen height < 600dp: room 200dp, character 90dp
- Screen height >= 600dp: room 250dp, character 110dp

## Dark Mode

방 씬은 "조명이 켜진 실내"로 다크모드에서도 밝은 색상 유지. 외곽 프레임만 다크 테마 outline 적용.

## Future

> 2026-04-20 개정: 원본 "P1+ future — List<RoomFurniture> 확장" 문구는 이미
> 구현된 `room_decoration` 피처(`MiniroomEquip` + 8 슬롯 + `PUT /me/room/miniroom`)
> 로 충족되었으므로 삭제. 아래는 그 다음 단계의 잔여 과제.

- **Slot 별 variant painter 확장** — §Equip Integration Contract 의 매핑 표에서 "기본 painter 고정" 으로 남아 있는 ceiling/window/shelf/plant/desk/rug 를 슬롯별 개별 slice 로 추가. 각 slice 는 `room-decoration.md:§Slot Catalog` 의 variant 리스트를 구현 범위로 삼는다.
- **Signature 아이템 렌더** — 챌린지 방 전용이지만 팔레트·레이어링 규칙은 본 문서와 공유. `room-decoration.md:§Signature Placement` 참고.
- **Dark mode 조명 variant** — "밤" 모드 시 창밖 밤하늘 + 전등 on. 현재는 다크모드에서도 방이 밝은 "조명 켜진 실내" 고정.
- **Stale cross-ref 교정 (별 건, 범위 밖)** — `docs/design/specs/character-cyworld-style.md:1104` 의 `"MiniroomScene — 아직 미구현, miniroom-cyworld.md 참조"` 주석은 2026-04-19 구현 후 stale. 해당 스펙 개정 시 함께 수정.

## Cyworld Reference

- Isometric/pseudo-3D room with wall + floor perspective
- Character stands INSIDE the room
- Pixel art aesthetic (already exists in CharacterAvatar 16x16 grid)
- Sky blue window (Cyworld brand color homage, adapted to pink theme)
- Compact room view in upper portion of screen
- Nostalgic Y2K/early-2000s vibe: rounded corners, playful, cute

## Related

### Code (기존 구현, 수정·확장 대상)

- `app/lib/core/widgets/miniroom_scene.dart` — 본 스펙의 주 대상. `equip` 파라미터·slot assetKey 분기.
- `app/lib/features/character/screens/my_room_screen.dart:107-112` — wiring 수정 지점.
- `app/lib/features/character/widgets/equip_stat_bar.dart` — 방 하단 능력치 바. 유지.
- `app/lib/features/room_decoration/providers/room_equip_provider.dart:17` — `myMiniroomProvider` (watch 대상).
- `app/lib/features/room_decoration/models/room_equip.dart` — `MiniroomEquip` 모델.
- `app/lib/features/room_decoration/screens/room_decorator_screen.dart` — 편집기. `equip` 전달 레퍼런스 구현.

### Design specs

- `docs/design/specs/room-decoration.md` — 8 슬롯 카탈로그·variant 가이드·API·경제.
- `docs/design/specs/challenge-room-social.md` — `MiniroomColors`·`depends-on: miniroom-cyworld`.
- `docs/design/specs/challenge-room-speech.md` — scene 직하부 입력 바.
- `docs/design/specs/character-cyworld-style.md` — 32×32 캐릭터 + 방 통합 픽셀 밀도.

### Reports

- `docs/reports/2026-04-19-feature-room-decoration.md` — P2 Phase 1+2 구현 기록. 본 개정의 context.
- `docs/reports/2026-04-20-design-miniroom-cyworld-revise.md` — 본 개정 작업 보고서.
