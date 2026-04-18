---
slug: miniroom-cyworld
status: ready
created: 2026-04-15
area: front
---

# My Room — Cyworld Miniroom Style Redesign

## Overview

"내 방" 화면을 2000년대 싸이월드 미니룸 스타일의 픽셀아트 방으로 변환한다. 현재의 평면적 캐릭터+스탯 레이아웃 대신, 벽/바닥/가구가 있는 작은 방 안에 캐릭터가 서 있는 형태.

## Design Concept

**3/4 탑뷰 픽셀아트 방** — 뒷벽이 화면 상단에 평면으로, 바닥이 아래쪽으로 깊이감을 주는 클래식 RPG/싸이월드 스타일.

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
      [스탯 오버레이]  (우상단 플로팅)
```

## Architecture

### New Files

1. **`app/lib/core/widgets/miniroom_scene.dart`** (~500-600 lines)
   - `MiniroomScene` — StatelessWidget, Stack 기반
   - `_MiniroomBackgroundPainter` — CustomPainter, 32x24 논리 그리드 (벽, 바닥, 뒤쪽 가구)
   - `_MiniroomForegroundPainter` — CustomPainter (캐릭터 앞 가구)
   - `MiniroomColors` — 색상 상수

2. **`app/lib/features/character/widgets/miniroom_stat_overlay.dart`** (~120-150 lines)
   - `MiniroomStatOverlay` — 반투명 블러 배경 플로팅 카드
   - `EquipStats` — 공개 스탯 클래스
   - `calcEquipStats()`, `getEquippedItems()` — 공개 유틸

### Modified Files

3. **`app/lib/features/character/screens/my_room_screen.dart`**
   - 상단 `SizedBox(h:180) > Row` → `MiniroomScene(h:250)` 교체
   - `_StatPanel` 등 제거 → overlay로 이동
   - TabBar: pill 인디케이터
   - `_ItemCard`: borderRadius 14→18, 그라디언트 배경

## Grid Layout (32x24)

| Element | Grid Position | Description |
|---------|---------------|-------------|
| Ceiling molding | rows 0-1 | Decorative line |
| Back wall | rows 2-11 | User background color tint (30% blend) |
| Window | cols 3-10, rows 3-9 | Sky blue glass + white cross-pane + cloud |
| Clock | cols 15-17, rows 3-5 | Circular face, two hands |
| Shelf | cols 22-30, rows 5-8 | Wood plank + books + mug |
| Baseboard | row 12 | Wall-floor edge |
| Floor | rows 12-23 | Checkerboard pattern (warm cream) |
| Desk | cols 1-8, rows 14-20 | Side view, wood, lamp on top |
| Rug | cols 10-22, rows 17-22 | Oval, wallTint variant |
| Plant | cols 26-29, rows 17-20 | Green leaves + brown pot |
| Character | center, rows 10-22 | Existing CharacterAvatar (110dp) |

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

```dart
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
    Positioned(right: 8, top: 8, child: MiniroomStatOverlay(stats: stats)),
  ],
)
```

## Stat Overlay

기존 `_StatPanel`을 추출하여 `BackdropFilter` 블러 배경의 compact 플로팅 카드로 리스타일.
- 위치: 방 씬 우상단
- 표시 항목: 💰 coinBoost, ⭐ verifyBonus, 🛡️ streakShield

## UI Style Updates

- **TabBar**: 둥근 pill indicator, 파스텔 핑크 배경
- **ItemCard**: borderRadius 18, 장착 시 그라디언트 배경
- **Room frame**: 3px rounded border (borderRadius 16), subtle shadow

## Responsive

- Screen height < 600dp: room 200dp, character 90dp
- Screen height >= 600dp: room 250dp, character 110dp

## Dark Mode

방 씬은 "조명이 켜진 실내"로 다크모드에서도 밝은 색상 유지. 외곽 프레임만 다크 테마 outline 적용.

## Future (P1+)

`_MiniroomBackgroundPainter`가 `List<RoomFurniture>`를 받도록 설계. 현재는 하드코딩된 기본 가구. 나중에 `GET /me/room/furniture` API로 방 꾸미기 확장 가능.

## Cyworld Reference

- Isometric/pseudo-3D room with wall + floor perspective
- Character stands INSIDE the room
- Pixel art aesthetic (already exists in CharacterAvatar 16x16 grid)
- Sky blue window (Cyworld brand color homage, adapted to pink theme)
- Compact room view in upper portion of screen
- Nostalgic Y2K/early-2000s vibe: rounded corners, playful, cute
