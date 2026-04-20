---
slug: character-cyworld-style
status: implemented
created: 2026-04-19
area: front
---

# Character Avatar — Cyworld Miniroom Style Redesign

## Overview

"내 방" 캐릭터(`CharacterAvatar`)를 2000년대 싸이월드 미니미 수준의 표현력으로 재디자인한다. 현재는 16×16 논리 그리드에 캐릭터 풋프린트가 10×16px 밖에 되지 않아 — 눈은 1~2px, 입은 4px, 팔은 2px 폭 막대 — 표정·의상 디테일·헤어 볼륨을 넣을 물리적 공간이 없다. 본 문서는 **32×32 그리드 + chibi 2.4-head 비율 + 3-tone 음영 시스템 + 소프트 아웃라인** 으로 전환하는 픽셀 아트 스펙이다.

이 문서는 `docs/design/miniroom-cyworld.md` (방 32×24 그리드) 와 같은 스케일을 채택해 방과 캐릭터의 시각 밀도를 통일한다. `docs/character-system-spec.md` 의 64×64 에셋 계약과 `CharacterData` 모델은 변경하지 않는다.

### Before / After 도식

```
BEFORE (16x16 grid, character = 10x16)        AFTER (32x32 grid, character = 22x30)

  0         10        16                       0         10        20      31
0 ····██████····                              0 ·········█████████············
  ···██░░░░██···                                ········██░░░░░░░██···········
2 ··██░░░░░░██··                                ·······██░░░░░░░░░██··········
  ··█░·█··█·█···   ← 눈 1px, 입 4px             ·······█░░███░░░███░█·········
  ··█░░░░░░░█···                                ·······█░░█◉█░░░█◉█░█·· ← 눈 4x4
6 ··█░·▂▂·····                                  ·······█░░███░░░███░█·········
  ···██████·····                                ·······█░░░░░░░░░░░█··········
8 ···█▓▓▓▓▓█····  ← 셔츠 flat 1색                ·······█░░░░·▂▂▂·░░█·· ← 입 U자
  ··█▓▓▓▓▓▓█···                                 ········█░░░░░░░░░█···········
  ··█▓▓▓▓▓▓█···                                 ·········███████████···········
  ··█▓▓▓▓▓▓█···                                12 ·········███████████·········· ← 목
12 ··█████████··                                  ········█▓▓▓▓▓▓▓▓▓▓█········ ← 상의 어깨
  ··█▓▓···▓▓█··                                   ·······█▓▓▓·▒▒▒·▓▓▓█······· ← 카라
  ··█▓▓···▓▓█··                                   ·······█▓▓▓▓▓▓▓▓▓▓▓█·······
  ··███····███·                                   ·······█▓▓▓·▒▒▒·▓▓▓█······· ← 단추/pocket
                                                  ·······█▓▓▓▓▓▓▓▓▓▓▓█·······
                                                22 ······█▓▓▓▓▓▓▓▓▓▓▓█········
                                                  ·········█████████·········· ← 벨트
                                                  ·········█△△△·△△△█·········· ← 바지 주름
                                                  ·········█△△△·△△△█··········
                                                  ·········█△△△·△△△█··········
                                                  ·········█△△△·△△△█··········
                                                30 ········███·····███········· ← 신발
                                                   ········███·····███·········
```

## Design Goals

싸이월드 미니미의 4가지 핵심 요소를 픽셀 단위로 재현한다.

1. **Chibi 비율** — 머리가 몸보다 크고 (약 2.4 heads tall), 팔다리는 짧고 통통. 귀여움·친근함이 우선.
2. **3-tone ramp** — 모든 파츠에 (soft outline · base · highlight) 3 tone 램프 적용. 좌상단 광원 가정, 우하단 shadow.
3. **표정 인식** — 눈은 최소 3×3 pupil + 흰자 + 하이라이트. 입은 2~4px 아치/점으로 감정 구분 가능.
4. **Soft outline** — 단색 검은 아웃라인 금지. 각 파츠는 base 색을 약 30% 어둡게 한 톤으로 1px 아웃라인.

## Architecture

### Target File (front 워크트리가 수정)

- `app/lib/core/widgets/character_avatar.dart` (L132-805, `_PixelCharacterPainter`)
  - `_drawBase`, `_drawBody`, `_drawLegs`, `_drawShoes`, `_drawEquipment`, 그리고 모든 `_draw*Equipment` 메서드의 좌표·색상 전면 재작성
  - 그리드: `final px = size.width / 16.0;` → **`final px = size.width / 32.0;`** (L237)
  - 클래스 이름·생성자 시그니처·`paintCharacterIntoCanvas` 공개 API 는 **불변**

### Public Contract (변경 금지)

| 요소 | 경로 | 유지 이유 |
|------|------|---------|
| `CharacterAvatar` 위젯 props | `character_avatar.dart:10-20` | 상위 호출부(miniroom_scene, my_room_screen, 상점 프리뷰) 영향 없도록 |
| `CharacterData` 필드 | `character_data.dart` | API/DB 계약 유지 (`skinTone/hairStyle/eyeStyle/hat/top/bottom/shoes/accessory`) |
| `paintCharacterIntoCanvas(canvas, character, dst)` | `character_avatar.dart:812-827` | 사진 스탬핑 기능 호환 |
| EPIC shimmer / accessory anim 훅 | `_shimmerController`, `_accessoryAnimController` | 애니메이션 파이프라인 보존 |
| `drawAccessoryOnCharacter` 호출 | `accessory_renderer.dart` | 좌표 offset 규칙만 본 문서가 제공 (§13) |

### Private Helper to Add

```dart
// 3-tone 페인팅 헬퍼 — 파츠 하나를 (base, shadow, highlight) 세 패스로 그림
void _paintLayer(
  Canvas canvas,
  double px, {
  required List<List<int>> base,
  List<List<int>> shadow = const [],
  List<List<int>> highlight = const [],
  required Color baseColor,
  required Color shadowColor,
  required Color highlightColor,
}) {
  _drawPixels(canvas, baseColor, base, px);
  _drawPixels(canvas, shadowColor, shadow, px);
  _drawPixels(canvas, highlightColor, highlight, px);
}
```

## Grid & Anchors (32×32)

**캔버스 배치**: 캐릭터는 캔버스 가로 중앙 정렬, 머리 꼭대기(col 10~21, row 2), 발 바닥(col 10~22, row 30)에 배치. 1~2px 여백을 상하좌우에 두어 그림자·장식을 수용.

### 논리 앵커 좌표

| Anchor | Position | Description |
|--------|----------|-------------|
| `HEAD_TOP_LEFT` | (10, 2) | 머리 bounding box 좌상단 |
| `HEAD_TOP_RIGHT` | (21, 2) | 머리 bounding box 우상단 |
| `HEAD_BOTTOM` | (10, 13) ~ (21, 13) | 턱선 |
| `EYE_L_CENTER` | (13, 11) | 왼눈 중심 (왼쪽 pupil 3×3 → cols 12-14, rows 10-12) |
| `EYE_R_CENTER` | (18, 11) | 오른눈 중심 (cols 17-19, rows 10-12) |
| `MOUTH_CENTER` | (15, 16) | 입 중심 (4px 기준 cols 14-17, row 16) |
| `BLUSH_L` | (12, 13) ~ (13, 13) | 왼볼 2×1 |
| `BLUSH_R` | (18, 13) ~ (19, 13) | 오른볼 2×1 |
| `NECK` | (14, 14) ~ (17, 14) | 목 4×1 (어깨로 자연스럽게 이어지도록 넓게) |
| `SHOULDER_L` | (11, 15) | 상의 왼어깨 기준점 |
| `SHOULDER_R` | (20, 15) | 상의 오른어깨 기준점 |
| `TORSO` | (11, 15) ~ (20, 21) | 상의 bounding box 10×7 |
| `ARM_L` | (9, 15) ~ (10, 20) | 왼팔 2×6 |
| `ARM_R` | (21, 15) ~ (22, 20) | 오른팔 2×6 |
| `HIP` | (12, 22) ~ (19, 22) | 바지 시작선 |
| `LEGS` | (12, 22) ~ (19, 28) | 다리 8×7 |
| `FOOT_L` | (11, 29) ~ (13, 30) | 왼발 3×2 |
| `FOOT_R` | (18, 29) ~ (20, 30) | 오른발 3×2 |

### 그리드 map (참고용 — 기본 캐릭터 기준)

```
col  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
row
 0   · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · ·
 1   · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · ·
 2   · · · · · · · · · · H H H H H H H H H H H H · · · · · · · · · ·    ← 머리 top
 3   · · · · · · · · · H H h h h h h h h h h h H H · · · · · · · · ·    ← 헤어 앞머리
 4   · · · · · · · · H H h h h h h h h h h h h h H H · · · · · · · ·
 5   · · · · · · · · H S S S S S S S S S S S S S S H · · · · · · · ·    ← 이마 skin
 6   · · · · · · · · H S S S S S S S S S S S S S S H · · · · · · · ·
 7   · · · · · · · · H S S S S S S S S S S S S S S H · · · · · · · ·
 8   · · · · · · · · H S S S S S S S S S S S S S S H · · · · · · · ·
 9   · · · · · · · · H S S S S S S S S S S S S S S H · · · · · · · ·
10   · · · · · · · · H S S S E E E S S S E E E S S H · · · · · · · ·    ← 눈 위
11   · · · · · · · · H S S S E O E S S S E O E S S H · · · · · · · ·    ← 눈동자 (O=white)
12   · · · · · · · · H S S S E E E S S S E E E S S H · · · · · · · ·    ← 눈 아래
13   · · · · · · · · H S S B B S S S S S S S B B S H · · · · · · · ·    ← 볼
14   · · · · · · · · H S S S S S M M M M S S S S S H · · · · · · · ·    ← 입 line
15   · · · · · · · · · H S S S S S S S S S S S S H · · · · · · · · ·    ← 턱
16   · · · · · · · · · · · · · · N N · · · · · · · · · · · · · · · ·    ← 목
17   · · · · · · · · · · · T T T T T T T T T T · · · · · · · · · · ·    ← 상의 어깨
18   · · · · · · · · · A T t t t c c t t t t T A · · · · · · · · · ·    ← A=팔, c=카라
19   · · · · · · · · · A T t t t t t t t t t T A · · · · · · · · · ·
20   · · · · · · · · · A T t t t t t t t t t T A · · · · · · · · · ·
21   · · · · · · · · · A T t t t t t t t t t T A · · · · · · · · · ·
22   · · · · · · · · · A T t t t t t t t t t T A · · · · · · · · · ·
23   · · · · · · · · · · T t t t t t t t t t T · · · · · · · · · · ·    ← 상의 hem
24   · · · · · · · · · · · L L L p p p p L L · · · · · · · · · · · ·    ← 벨트 (L=다리외곽)
25   · · · · · · · · · · · L p p p · p p p L · · · · · · · · · · · ·    ← 바지 (p) 시작
26   · · · · · · · · · · · L p p p · p p p L · · · · · · · · · · · ·
27   · · · · · · · · · · · L p p p · p p p L · · · · · · · · · · · ·
28   · · · · · · · · · · · L p p p · p p p L · · · · · · · · · · · ·
29   · · · · · · · · · · F F F · · · · F F F · · · · · · · · · · · ·    ← 신발
30   · · · · · · · · · · F F F · · · · F F F · · · · · · · · · · · ·
31   · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · ·
```

범례: `H`=hair/outline, `h`=hair base, `S`=skin, `E`=eye outline, `O`=eye white, `B`=blush, `M`=mouth, `N`=neck, `T`=top outline, `t`=top base, `c`=collar detail, `A`=arm, `L`=leg outline, `p`=pants, `F`=shoe.

## Proportions

| Part | Width | Height | Grid Position | Head-size Ratio |
|------|-------|--------|---------------|-----------------|
| **Head (hair+skin)** | 12 | 12 | (10,2)-(21,13) | **1.0 head** |
| Face (skin only) | 10 | 9 | (11,5)-(20,13) | — |
| Hair cover | 12 | 3 | (10,2)-(21,4) | — |
| Neck | 2 | 2 | (14,14)-(15,15) | — |
| Torso | 10 | 7 | (11,17)-(20,23) | 0.58 head |
| Arms (L/R) | 2 | 6 | (9,17)-(10,22) / (21,17)-(22,22) | — |
| Legs (bottom) | 8 | 5 | (12,24)-(19,28) | 0.42 head |
| Feet (L/R) | 3 | 2 | (11,29)-(13,30) / (18,29)-(20,30) | — |

**Total height**: 29px (rows 2-30). **Head / total = 12 / 29 ≈ 0.41** → 약 2.4-heads tall (미니미 비율 준수).

### 좌우 대칭 원칙

캐릭터는 완전 좌우 대칭. 거울축 = `col 15.5` (15와 16 사이). `EYE_L_CENTER(13,11)` 의 거울 = `EYE_R_CENTER(18,11)` 처럼 `x_mirror = 31 - x` 로 계산. 비대칭 element(예: beret 의 왼쪽 기울기, accessory 의 한손 들기) 만 예외 허용.

## Color System

### Palette Constants

```dart
/// 32x32 캐릭터 전용 팔레트. 모든 파츠는 3-tone ramp 를 가진다.
/// 키 포맷: `<part>_<tone>` (tone: shadow < base < highlight)
class CharacterPalette {
  // ─── Skin (3 skintone × 3 tone = 9색) ────────────────────────
  // fair
  static const skinFairShadow    = Color(0xFFF2B891); // 좌하단 그림자
  static const skinFairBase      = Color(0xFFFFCBA4); // 메인
  static const skinFairHighlight = Color(0xFFFFE1C7); // 우상단 광원
  // light
  static const skinLightShadow    = Color(0xFFF7D9B8);
  static const skinLightBase      = Color(0xFFFFF0DB);
  static const skinLightHighlight = Color(0xFFFFF8EC);
  // dark
  static const skinDarkShadow    = Color(0xFF6B3E18);
  static const skinDarkBase      = Color(0xFF8D5524);
  static const skinDarkHighlight = Color(0xFFB47B4A);

  // ─── Hair (default brown — 추후 hairColor 필드 확장 시 증식) ────
  static const hairOutline   = Color(0xFF3A2010); // 진한 아웃라인
  static const hairShadow    = Color(0xFF4A2812);
  static const hairBase      = Color(0xFF5D3A1A); // 기존 _hairBrown 승계
  static const hairHighlight = Color(0xFF8B5A2B); // 부드러운 갈색 하이라이트

  // ─── Face features ───────────────────────────────────────────
  static const eyeOutline  = Color(0xFF2D1B00); // pupil 테두리
  static const eyePupil    = Color(0xFF3A1F0A);
  static const eyeWhite    = Color(0xFFFFFFFF);
  static const eyeShine    = Color(0xFFFFF8E1); // 반짝임 point

  static const blushBase   = Color(0xFFFFB3B3);
  static const blushSoft   = Color(0xFFFFD9D9); // 바깥 톤 소프트

  static const mouthLine   = Color(0xFF8B4513);
  static const mouthDark   = Color(0xFF6B3A10);
  static const lipTint     = Color(0xFFD26B6B); // 여자 캐릭 립 강조용 (선택적)

  // ─── Outline derivation rule ─────────────────────────────────
  // 의상 파츠 아웃라인은 항상 base 색의 HSL L 값을 -0.20 한 색.
  // (Dart 구현: HSLColor.fromColor(base).withLightness((l-0.2).clamp(0,1)).toColor())
  // 다음 상수들은 이 규칙을 적용한 결과를 미리 계산해 박아둔 값.

  // ─── Default fallback clothing (equipment 없을 때) ──────────
  static const defaultShirtBase      = Color(0xFFF5F5F5);
  static const defaultShirtShadow    = Color(0xFFDCDCDC);
  static const defaultShirtHighlight = Color(0xFFFFFFFF);
  static const defaultShirtOutline   = Color(0xFFA9A9A9);

  static const defaultPantsBase      = Color(0xFF5B88C4);
  static const defaultPantsShadow    = Color(0xFF3E6CA3);
  static const defaultPantsHighlight = Color(0xFF7FA5D6);
  static const defaultPantsOutline   = Color(0xFF2F4E7A);

  static const defaultShoesBase      = Color(0xFF8B6914);
  static const defaultShoesShadow    = Color(0xFF5F4508);
  static const defaultShoesHighlight = Color(0xFFB08838);
  static const defaultShoesOutline   = Color(0xFF3E2C04);

  // ─── Effects ────────────────────────────────────────────────
  static const sparkleWhite = Color(0xCCFFFFFF);
  static const sparkleGold  = Color(0xFFFFF4B3);
}
```

### Tone Application Rule

모든 파츠에 동일 규칙:

- **Shadow**: base 의 HSL Lightness − 0.20. 우하단 1~2 열/행에 주로 배치.
- **Base**: 메인 색.
- **Highlight**: base 의 HSL Lightness + 0.15. 좌상단 1 열/행에 1~2 px.
- **Outline (soft)**: base 의 HSL Lightness − 0.35. 1px 외곽선.

광원 방향: **좌상단 (north-west)**. 이것은 방의 창문이 왼쪽 벽에 있는 `miniroom-cyworld.md:68-69` 레이아웃과 일치시키기 위함.

## Face Spec

### Eyes (3 style × left/right)

#### round (기본)

```
col 12 13 14            col 17 18 19
row 10   E  E  E         row 10  E  E  E     ← 상단 outline
row 11   E  O  E              11  E  O  E    ← O=eye white (좌우 대칭, 왼눈은 O를 왼쪽에 치우치게)
row 12   E  E  E              12  E  E  E    ← 하단 outline
```

- **왼눈**: outline `(12,10)(13,10)(14,10)(12,11)(14,11)(12,12)(13,12)(14,12)`, white `(13,11)`, shine `(12,10)` (좌상단 whites pixel 1개로 하이라이트 대신)
- **오른눈**: 거울 대칭

#### sharp (날카로운 아몬드형)

```
col 12 13 14 15         col 16 17 18 19
row 10   E  E  E  E      row 10  E  E  E  E   ← 얇고 길게 4x1
row 11   E  O  O  e      row 11  e  O  O  E   ← 속눈썹 한 픽셀 (e)
```

- 왼눈 outline: `(12,10)(13,10)(14,10)(15,10)(12,11)`  
  속눈썹(짙은 아웃라인): `(15,11)`  
  whites: `(13,11)(14,11)`
- 오른눈 거울 대칭

#### sleepy (졸린 눈)

```
col 12 13 14 15          col 16 17 18 19
row 11   E  E  E  E       row 11  E  E  E  E   ← 한 줄 arc
row 12   ·  O  O  ·       row 12  ·  O  O  ·   ← 아래 whites 2px (살짝 보임)
```

- 왼눈 outline: `(12,11)(13,11)(14,11)(15,11)`, whites: `(13,12)(14,12)`
- 오른눈 거울 대칭

### Mouth (3 style)

| Style | Pixels | Tone |
|-------|--------|------|
| smile | `(14,15)(17,15)` + `(15,16)(16,16)` 하단 기울기 → U자 | `mouthLine` + `mouthDark` (양끝 pixel) |
| smirk | `(14,16)(15,16)` 왼쪽만 | `mouthLine` 단일 |
| neutral | `(15,16)(16,16)` | `mouthLine` |

### Blush

양 볼에 4-pixel patch, 2-tone:

- 왼볼 base: `(12,13)(13,13)` — `blushBase`
- 왼볼 soft: `(11,13)(14,13)` — `blushSoft` (외곽 페이드)
- 오른볼: `(18,13)(19,13)` base, `(17,13)(20,13)` soft

## Hair Spec

### short (기본)

```
아웃라인:
 (10,3)(11,3)(20,3)(21,3)            ← 옆머리
 (9,4)(10,4)(21,4)(22,4)
 (10,2)(11,2)(12,2)(13,2)(14,2)(15,2)(16,2)(17,2)(18,2)(19,2)(20,2)(21,2)  ← 정수리 outline

앞머리 base:
 (11,3)(12,3)(13,3)(14,3)(15,3)(16,3)(17,3)(18,3)(19,3)(20,3)
 (12,4)(13,4)(14,4)(17,4)(18,4)(19,4)    ← 앞머리 중앙 splitting

앞머리 highlight (2px 하이라이트 strip):
 (13,3)(14,3)     ← 좌상단 광택
```

### long

```
short 의 outline·base 에 추가로 양옆 귀밑 흐름:
 outline: (9,5)(9,6)(9,7)(22,5)(22,6)(22,7)    ← 귀밑 선
          (10,8)(10,9)(21,8)(21,9)             ← 어깨 위 hair end
 base:    (10,5)(10,6)(10,7)(21,5)(21,6)(21,7)
 highlight: (10,5)(21,5)                       ← 빛 닿는 꼭대기
```

### curly

```
외곽 윤곽이 wave:
 outline: (10,2)(13,2)(16,2)(19,2)(11,1)(14,1)(17,1)(20,1)    ← 울퉁불퉁 정수리
          (9,3)(9,4)(22,3)(22,4)(9,5)(22,5)                   ← 양옆 볼륨
 base (앞머리 + 볼륨):
   (10,3)(11,3)(12,3)(13,3)(14,3)(15,3)(16,3)(17,3)(18,3)(19,3)(20,3)(21,3)
   (10,4)(11,4)(12,4)(19,4)(20,4)(21,4)
 highlight (컬마다 빛 1점):
   (11,2)(14,2)(17,2)(20,2)
```

## Body / Skin Layers

### Face Skin (base + shadow + highlight)

```
base (전체):
 rows 5-14 에서 (col 11-20) 가 기본. 단, row 2-4 는 hair 덮여서 안보임. row 15 는 턱끝(col 12-19)만.

shadow (턱·볼 우측 음영):
 (20,6)(20,7)(20,8)(19,9)(19,10)(19,11)(19,12)(19,13)(19,14)(18,15)

highlight (이마 좌상 광택):
 (11,5)(12,5)(11,6)
```

### Neck & Shoulders Skin

```
목:
 base:    (14,14)(15,14)(16,14)(17,14) (15,15)(16,15)
 shadow:  (17,14)
```

### Arms Skin (기본 — 상의 입으면 소매가 덮음)

```
왼팔 base: (9,17)(10,17)(9,18)(10,18)(9,19)(10,19)(9,20)(10,20)(9,21)(10,21)(9,22)(10,22)
왼팔 shadow: (10,20)(10,21)(10,22)  ← 오른쪽(몸통 쪽) 은 미약한 음영
오른팔 base/shadow: 거울 대칭
```

### Legs Skin (shorts 일 때만 노출)

```
shorts 시 노출 구간: rows 25-28
왼다리: base (12,25-28)(13,25-28)(14,25-28)
오른다리: base (17,25-28)(18,25-28)(19,25-28)
shadow: 각 다리 오른쪽 1px 열
```

## Hat Redesigns (6종)

각 hat 은 rows 0~4 영역을 사용. 머리 outline(row 2-4) 을 일부 덮을 수 있음. 3-tone (shadow/base/highlight) + 외곽 1px outline 규칙.

### hat/cap (빨간 야구모자)

```
base (red #E53935) — 크라운:
 (10,2)(11,2)(12,2)(13,2)(14,2)(15,2)(16,2)(17,2)(18,2)(19,2)(20,2)(21,2)
 (9,3)(10,3)(11,3)(12,3)(13,3)(14,3)(15,3)(16,3)(17,3)(18,3)(19,3)(20,3)(21,3)(22,3)
 (9,4)(10,4)(11,4)(12,4)(19,4)(20,4)(21,4)(22,4)  ← 옆 볼륨

chin/brim (챙 — 얼굴 위로 그림자):
 shadow #B71C1C: (7,5)(8,5)(9,5)(10,5)(11,5)(12,5)(13,5)
                 (7,6)(8,6)(9,6)   ← 챙 두께
 base   #C62828: (14,5)(15,5)(16,5)(17,5)(18,5)

outline #8B1515: (10,1)(11,1)(12,1)(13,1)(14,1)(15,1)(16,1)(17,1)(18,1)(19,1)(20,1)(21,1)
                 (8,2)(23,2)(8,3)(23,3)
                 (6,5)(14,6)    ← 챙 끝

highlight #FFCDD2: (11,3)(12,3)(13,3)      ← 좌상단 광택
                   (9,5)                    ← 챙 반사광

logo dot #FFFFFF: (15,3)   ← 심플 로고 1 pixel
```

### hat/beanie (파란) / hat/pink_beanie (분홍)

색상만 교체 (pink: base `#FF80AB`, light `#FFCDD2` / blue: base `#1976D2`, light `#90CAF9`).

```
crown base:
 (11,1)(12,1)(13,1)(14,1)(15,1)(16,1)(17,1)(18,1)(19,1)(20,1)
 (10,2)-(21,2) 12 px
 (9,3)-(22,3)  14 px
 (9,4)-(22,4)  14 px

brim (접힌 부분 — 더 진한 톤):
 shadow: (9,5)(10,5)(11,5)(12,5)(13,5)(14,5)(15,5)(16,5)(17,5)(18,5)(19,5)(20,5)(21,5)(22,5)

ribbed stripe (beanieLight):
 (11,2)(13,2)(15,2)(17,2)(19,2)
 (11,4)(13,4)(15,4)(17,4)(19,4)

pom-pom (꼭대기 뽀글):
 white:   (14,0)(15,0)(16,0)(17,0)
           (13,1)(14,1)(15,1)(16,1)(17,1)(18,1)  ← 흰색 확장
           (15,-1) 없음 — row 0 부터
 shadow:  (13,1)(18,1)
 highlight:(14,0)
```

### hat/headband (노란 머리띠)

얇은 2px 밴드 + 큰 나비 매듭.

```
band base (#FFD600):
 (10,3)(11,3)(12,3)(13,3)(14,3)(15,3)(16,3)(17,3)(18,3)(19,3)(20,3)(21,3)
 (10,4)(11,4)(12,4)(13,4)(14,4)(15,4)(16,4)(17,4)(18,4)(19,4)(20,4)(21,4)

ribbon bow (오른쪽 기울기):
 base #FF8F00: (20,1)(21,1)(22,1)(23,1)
               (20,2)(21,2)(22,2)(23,2)
 outline darker: (19,1)(24,1)(19,2)(24,2)(20,3)(21,3)(22,3)(23,3)
 knot center: (21,2)(22,2) 어두운 accent

outline #B58900: 밴드 외곽 1px
highlight #FFF59D: (11,3)(12,3) 광택 2px
```

### hat/fedora (갈색 중절모)

```
크라운 (둥근 윗부분):
 base #795548:
  (12,1)(13,1)(14,1)(15,1)(16,1)(17,1)(18,1)(19,1)
  (11,2)(12,2)(13,2)(14,2)(15,2)(16,2)(17,2)(18,2)(19,2)(20,2)
  (11,3)(12,3)(13,3)(14,3)(15,3)(16,3)(17,3)(18,3)(19,3)(20,3)

chin dimple (크라운 중앙 눌림):
 shadow #5D4037: (15,1)(16,1)(15,2)(16,2)

brim (챙 — 넓은 양옆):
 base #5D4037:
   (8,4)(9,4)(10,4)(11,4)(12,4)...(22,4)(23,4)     ← 넓은 챙 16px
 shadow: (8,5)(9,5)(22,5)(23,5)       ← 챙 두께 1px

band (리본):
 base #FFCC80: (11,3)(12,3)(13,3)(14,3)(15,3)(16,3)(17,3)(18,3)(19,3)(20,3)  ← row 3 중 band 가로
 accent #E65100: (15,3)(16,3)  ← 중앙 매듭

outline #3E2723: 크라운 상단 + 챙 외곽

highlight #A1887F: (12,2)(13,2)(20,3)    ← 우측 광택
```

### hat/beret (진홍 베레모, 왼쪽으로 기울어진)

```
base #8D1515 (기울어진 원형):
 (9,2)(10,2)(11,2)(12,2)(13,2)(14,2)(15,2)(16,2)(17,2)(18,2)(19,2)(20,2)(21,2)
 (8,3)(9,3)(10,3)(11,3)(12,3)(13,3)(14,3)(15,3)(16,3)(17,3)(18,3)(19,3)(20,3)(21,3)
 (8,4)(9,4)(10,4)(11,4)(12,4)            ← 왼쪽 하단으로 삐져나옴

stem (꼭대기 꼭지):
 base: (9,1)(10,1)
 outline: (8,1)(11,1)(9,0)(10,0)

highlight #B71C1C:
 (11,2)(12,2)(13,2)    ← 왼쪽 위 빛
 (9,1)                 ← 꼭지 반사

outline #5C0F0F: 외곽 1px + 꼭지 외곽
```

### hat/crown (황금 왕관, EPIC 전용)

5 개 포인트 + 중앙 2 젬.

```
base gold (rarity EPIC → #FFD700 / 그 외 → #E6B800):
 (10,3)(11,3)(12,3)(13,3)(14,3)(15,3)(16,3)(17,3)(18,3)(19,3)(20,3)(21,3)   ← 밴드 가로
 (10,4)(11,4)(12,4)(13,4)(14,4)(15,4)(16,4)(17,4)(18,4)(19,4)(20,4)(21,4)

points (5개 뾰족):
 (10,2)(11,2)                                                  ← 1번 point
 (13,1)(13,2)(14,1)                                            ← 2번 point
 (15,0)(16,0)(15,1)(16,1)(15,2)(16,2)                          ← 중앙 높은 point
 (17,1)(18,1)(18,2)                                            ← 4번 point
 (20,2)(21,2)                                                  ← 5번 point

jewels (분홍·파랑):
 #E91E63: (14,4)     ← 분홍 루비
 #2196F3: (17,4)     ← 푸른 사파이어

highlight white:
 (10,3)(15,0)(21,3)    ← 양끝 + 꼭대기 광택

outline #B8860B: 밴드·포인트 외곽

+ EPIC 셰이머: §14 참조
```

## Top Redesigns (7종)

모든 top 은 torso bounding box (cols 11-20, rows 17-23) + 어깨 seam (row 17) + 팔 소매 (cols 9-10, 21-22, rows 17-22) 을 cover.

각 파츠는 4-layer 구성 **(base / shadow / highlight / outline)** + 디테일 accent (collar, button, hem, sleeve cuff).

### top/white_tee (하얀 티셔츠)

```
body base #F5F5F5:
 (11,17)(12,17)...(20,17)          ← 어깨 10px
 (11,18)-(20,18)
 (11,19)-(20,19)
 (11,20)-(20,20)
 (11,21)-(20,21)
 (11,22)-(20,22)
 (12,23)-(19,23)                    ← hem 살짝 좁게

sleeves (소매):
 (9,18)(10,18)(9,19)(10,19)(9,20)(10,20)    ← 왼소매 2x3
 (21,18)(22,18)(21,19)(22,19)(21,20)(22,20) ← 오른소매

body shadow #DCDCDC:
 (20,19)(20,20)(20,21)(20,22)               ← 우측 음영 세로 1열
 (11,23)(19,23)                              ← hem 양끝 어둡게

highlight #FFFFFF:
 (12,17)(13,17)                              ← 어깨 광택
 (11,18)                                     ← 왼어깨 점

outline #A9A9A9:
 (11,17)(20,17)                              ← 어깨 끝
 (10,18)(10,19)(10,20)(10,21)(10,22)        ← 좌측 몸통 외곽 (팔과 구분)
 (21,18)(21,19)(21,20)(21,21)(21,22)        ← 우측
 (12,23)(19,23)                              ← hem outline

collar accent #CCCCCC (V 네크라인):
 (14,17)(15,17)(16,17)(17,17)                ← 카라 윗선
 (15,18)(16,18)                              ← 깊게 패인 점
```

### top/striped_tee (파랑·흰 줄무늬)

`white_tee` 의 base 패턴 유지하되 row 단위로 blue/white 교대:

```
blue stripes #1976D2: rows 17, 19, 21, 23 의 body pixel
white stripes #FFFFFF: rows 18, 20, 22 의 body pixel
sleeve stripes: 같은 규칙으로 소매에도 적용

shadow (blue → darker #0D47A1): row 17,19,21 의 가장 오른쪽 column
highlight (white): row 18 왼어깨 point (12,18)
outline: 몸통 외곽 + 각 stripe 경계선 생략 (줄무늬 자체가 구분선 역할)
collar: 둥근 네크 — 대신 (15,17)(16,17) 2px 만 흰색으로 강조
```

### top/check_shirt (빨강 체크 셔츠)

```
pattern: 2x2 타일로 red / cream 교대 (체커보드).
  red #D32F2F at (11,17)(12,17)(15,17)(16,17)(19,17)(20,17)
              + (11,18)(12,18)(15,18)(16,18)(19,18)(20,18)
              + 3x3 행마다 반복...
  cream #FFF8E1 at (13,17)(14,17)(17,17)(18,17) + 대응 행
  소매도 동일 pattern

collar (플란넬 셔츠 카라):
 base #B71C1C:
  (13,17)(14,17)(17,17)(18,17)    ← 카라 상단
  (14,18)(17,18)                   ← 카라 깊이
 accent #FFF8E1: (15,18)(16,18)    ← 카라 중앙 갭

buttons #8B1515:
 (15,19)(15,21)(15,23)            ← 3 버튼 세로

shadow: 각 red tile 의 우하단 1px 을 #8B1515 로
highlight: 각 cream tile 의 좌상단 1px 을 #FFFEF0
outline: 몸통·소매 외곽
```

### top/sleeveless (민소매 초록)

```
body base #388E3C:
 (12,17)-(19,17)                   ← 어깨 좁아짐 (8px)
 (12,18)-(19,18)
 (12,19)-(19,19)
 (12,20)-(19,20)
 (12,21)-(19,21)
 (12,22)-(19,22)
 (13,23)-(18,23)

어깨 스트랩 (넥홀 좁게):
 (13,17)(14,17)(17,17)(18,17) 만 남김   ← 가슴중앙 (15,17)(16,17) 은 skin 노출
 skin 노출: (15,17)(16,17) 에 skinBase 재페인트

소매 없음: 팔 (9,17)-(10,22), (21,17)-(22,22) 는 기본 skin arm 유지

shadow #1B5E20: (19,19)(19,20)(19,21)(19,22)(18,23)
highlight #81C784: (13,17)(14,17)

outline #1B5E20: 몸통 외곽
```

### top/hoodie (파랑 후드)

```
body base #1565C0:
 (10,17)-(21,17)   ← 어깨 더 넓음 (후드 볼륨)
 (10,18)-(21,18)
 (11,19)-(20,19)
 (11,20)-(20,20)
 (11,21)-(20,21)
 (11,22)-(20,22)
 (12,23)-(19,23)

hood (머리 뒤 후드 볼륨 — head 옆으로 살짝 튀어나옴):
 (8,13)(9,13)(22,13)(23,13)                ← 목 옆 후드 덩어리
 (8,14)(9,14)(22,14)(23,14)
 (8,15)(9,15)(22,15)(23,15)(10,15)(21,15)
 (10,16)(11,16)(12,16)...(19,16)(20,16)(21,16)  ← 후드 깃

hood shadow #0D47A1:
 (9,14)(9,15)(22,14)(22,15)                 ← 후드 안쪽 그림자
 (15,16)(16,16)                              ← 목 뒤 어두운 점

drawstrings:
 base #FFFFFF: (14,16)(15,16)(16,16)(17,16)  ← 후드끈 가로
 tips #5D4037: (14,17)(17,17)                 ← 끈 끝

pouch (앞 주머니):
 base #1976D2: (13,20)(14,20)(15,20)(16,20)(17,20)(18,20)
               (13,21)(18,21)

sleeves: 소매 cuff 에 ribbed 느낌
 cuff base: (9,21)(10,21)(21,21)(22,21)
 cuff line: (9,22)(10,22)(21,22)(22,22)

highlight: (11,17)(12,17)(13,17)
outline #0A3880: 몸통·후드·소매 외곽
```

### top/cardigan (갈색 오픈 카디건 + 노랑 이너)

```
cardigan base #8D6E63 (좌우 패널만):
 (11,17)-(13,17)(18,17)-(20,17)
 (11,18)-(13,18)(18,18)-(20,18)
 (11,19)-(13,19)(18,19)-(20,19)
 (11,20)-(13,20)(18,20)-(20,20)
 (11,21)-(13,21)(18,21)-(20,21)
 (11,22)-(13,22)(18,22)-(20,22)
 (12,23)-(13,23)(18,23)-(19,23)

inner shirt #FFF9C4 (중앙 열린 부분):
 (14,17)-(17,17)
 (14,18)-(17,18)
 (14,19)-(17,19)
 (14,20)-(17,20)
 (14,21)-(17,21)
 (14,22)-(17,22)
 (14,23)-(17,23)

buttons #5D4037 (이너 위):
 (15,19)(15,21)(15,23)

sleeves: 카디건 색으로 전체
 (9,17)-(10,22)(21,17)-(22,22)

shadow #6D4C41: (13,18)(13,19)(13,20)(13,21)(13,22)  ← 카디건 안쪽 접히는 선
                 (18,18)(18,19)(18,20)(18,21)(18,22)
highlight #BCAAA4: (11,17)(12,17)
outline #4E342E: 카디건 전체 외곽 + 팔 외곽
```

### top/tuxedo (검정 턱시도 + 흰 셔츠 + 빨강 나비넥타이 — EPIC)

```
jacket base #212121:
 (11,17)-(13,17)(18,17)-(20,17)
 (11,18)-(13,18)(18,18)-(20,18)
 (11,19)-(13,19)(18,19)-(20,19)
 (11,20)-(13,20)(18,20)-(20,20)
 (11,21)-(13,21)(18,21)-(20,21)
 (11,22)-(13,22)(18,22)-(20,22)
 (11,23)(19,23)

white shirt (중앙):
 base #FFFFFF:
  (14,17)-(17,17)
  (14,18)-(17,18)
  (14,19)-(17,19)
  (14,20)-(17,20)
  (14,21)-(17,21)
  (14,22)-(17,22)
  (14,23)-(17,23)

collar (V자 jacket 라펠):
 base #0A0A0A: (13,17)(18,17)(13,18)(18,18)        ← 날카로운 라펠

bowtie (빨강 나비):
 base #FF1744:
  (14,17)(15,17)(16,17)(17,17)
  (14,18)(17,18)                    ← 양쪽 날개
 knot darker #B71C1C: (15,18)(16,18)

buttons #BDBDBD (더블 브레스트):
 (13,20)(18,20)(13,22)(18,22)

sleeves: 재킷 색 + cuff
 (9,17)-(10,22)(21,17)-(22,22) base
 cuff white line: (9,22)(10,22) outline + (21,22)(22,22)

shadow #000000: (13,22)(13,23)(18,22)(18,23)
highlight #424242: (11,17)(20,17)
outline: jacket 외곽 동일

+ EPIC 셰이머: §14
```

## Bottom Redesigns (6종)

bottom bounding box: cols 11-20, rows 22-28 (벨트 라인 row 22, 다리 25-28, 허벅지·정강이 분리).

기본 구조:
- **벨트/허리 1px** (row 22)
- **엉덩이 2px** (rows 23-24)
- **다리 갈라짐** (rows 25-28, 중앙 1px 은 skin or shadow)

### bottom/jeans (진청 데님)

```
base #1565C0:
 belt:    (11,22)(12,22)...(20,22)           ← 10px 벨트
 hip:     (11,23)-(20,23)(11,24)-(20,24)
 legs L:  (12,25)-(14,25)(12,26)-(14,26)(12,27)-(14,27)(12,28)-(14,28)
 legs R:  (17,25)-(19,25)(17,26)-(19,26)(17,27)-(19,27)(17,28)-(19,28)
 crotch gap: (15,25)(16,25)...(15,28)(16,28)  ← 다리 사이 1-2px 은 base 말고 shadow

shadow #0D47A1:
 (20,23)(20,24)(14,25)(14,26)(14,27)(14,28)  ← 우측 세로 음영
 (19,25)(19,26)(19,27)(19,28)                ← 오른다리 외측
 (15,25)(15,26)(15,27)(15,28)(16,25)(16,26)(16,27)(16,28) ← 다리사이 깊은 접힘

highlight #42A5F5:
 (11,22)(12,22)(11,23)                        ← 벨트 왼쪽 광택
 (12,25)(12,26)                               ← 왼다리 앞면
 (17,25)                                      ← 오른다리 앞면

outline #0A3880: 벨트·다리 외곽 1px

pockets #0A3880:
 (11,23)(20,23)                               ← 양쪽 허리선 포켓 상단
 (11,24)(12,24)(19,24)(20,24)                 ← 포켓 크기

belt buckle #FFD700:
 (15,22)                                       ← 금속 버클 1px
```

### bottom/shorts (카키 반바지)

```
base #C8A96E:
 belt + hip + 다리 2 rows only:
  (11,22)-(20,22)(11,23)-(20,23)(11,24)-(20,24)
  (12,25)-(14,25)(17,25)-(19,25)                ← 1-row 만 다리 덮음

노출 다리 skin:
 (12,26)-(14,26)(12,27)-(14,27)(12,28)-(14,28)  ← 왼다리 skin
 (17,26)-(19,26)...(17,28)-(19,28)               ← 오른다리 skin
 + skin shadow 각 다리 우측 1 column

shadow #8B7A50: (20,23)(20,24)(14,25)(19,25)
highlight #E6D4A8: (11,22)(12,22)
outline: #6D5F3E 외곽

drawstring (끈 디테일):
 #6D5F3E: (15,22)(16,22)   ← 허리 중앙 매듭점
```

### bottom/chinos (베이지 치노)

```
base #D4B896:
 belt + hip + 전체 다리 (jeans 와 같은 footprint)

shadow #A68B5F:
 우측 세로 + 다리사이 접힘

highlight #EAD3AE:
 (11,22)(12,22)(12,25)(17,25)

outline #8B7345:
 외곽

belt 고리 (loops) #8B7345:
 (13,22)(17,22)    ← 허리고리 2점
center pleat (주름):
 shadow line: (13,25)(13,26)(13,27)(13,28)(18,25)(18,26)(18,27)(18,28)  ← 가운데 각 다리 세로선 1px
```

### bottom/skirt (분홍 스커트, A라인)

```
A라인 (아래로 갈수록 넓어짐):
 base #EC407A:
  belt:    (12,22)(13,22)...(19,22)             ← 허리는 좁게 8px
  row 23:  (12,23)-(19,23)
  row 24:  (11,24)-(20,24)                      ← 1px 씩 퍼짐
  row 25:  (11,25)-(20,25)
  row 26:  (10,26)-(21,26)                      ← 2px 퍼짐
  row 27:  (10,27)-(21,27)
  row 28:  (9,28)-(22,28)                       ← 최대폭

pleat lines (주름):
 shadow #AD1457: (13,24)(16,24)(19,24)
                  (13,25)(16,25)(19,25)
                  (13,26)(16,26)(19,26)
                  (13,27)(16,27)(19,27)
                  (13,28)(16,28)(19,28)

ruffle hem (밑단 러플):
 base #F48FB1: (9,29)(10,29)(11,29)(20,29)(21,29)(22,29)  ← 살짝 삐져나오는 장식
 단, 이 부분은 shoes 와 겹칠 수 있으니 shoes 앞에 먼저 그리고 shoes 가 덮기

highlight #F8BBD0:
 (12,22)(13,22)    ← 허리 광택
 (12,27)            ← 주름 사이 빛

outline #880E4F:
 러플 외곽 + 허리 외곽
```

### bottom/cargo (올리브 카고)

```
base #558B2F:
 wider footprint: cols 10-21 (전체 2px 더 넓게)
  (10,22)-(21,22)(10,23)-(21,23)(10,24)-(21,24)
  (10,25)-(14,25)(17,25)-(21,25)
  (10,26)-(14,26)(17,26)-(21,26)
  (10,27)-(14,27)(17,27)-(21,27)
  (10,28)-(14,28)(17,28)-(21,28)

cargo pockets (양 허벅지 대형 포켓):
 base darker #33691E:
  (10,24)(11,24)(10,25)(11,25)(10,26)(11,26)     ← 왼 카고 포켓
  (20,24)(21,24)(20,25)(21,25)(20,26)(21,26)     ← 오른 카고 포켓
 pocket flap: (10,24)(11,24)(20,24)(21,24) 밝기 +1
 button #8D6E63:
  (11,25)(20,25)

shadow #2E5420: 우측 세로 + 다리사이
highlight #8BC34A: (11,22)(12,22)(11,25)(20,25)
outline #1B3D0E: 전체 외곽
```

### bottom/golden_pants (황금 EPIC 바지)

```
jeans 동일 풋프린트에 gold 톤 적용:

base #FFD700:
 벨트 + 엉덩이 + 양 다리 (jeans 패턴 그대로)

shadow #FF8F00:
 우측 세로 + 다리 안쪽 접힘 (패턴은 jeans 와 동일 위치)

highlight #FFFDE7:
 (11,22)(12,22)(11,23)     ← 밝은 반짝
 (12,25)(17,25)             ← 다리 앞면 하이라이트

sparkle dot (고정 반짝 1-pixel):
 (13,23)(18,24)(14,26)(18,28) 각각 #FFFFFF

outline #B8860B: 외곽

+ EPIC 셰이머: §14
```

## Shoes Redesigns (6종)

shoes bounding box: cols 10-13, 18-21 × rows 29-30. 3-part anatomy:
- **top (갑피)**: row 29
- **toe-box (발끝)**: row 30 앞 1-2px
- **sole (밑창)**: row 30 전체 바닥 1px

### shoes/sneakers (파랑 스니커즈)

```
왼발 sneaker:
 upper base #42A5F5:
  (11,29)(12,29)(13,29)         ← 갑피 3px
 toe-box (앞코 하얀 고무):
  #FFFFFF: (11,30)(12,30)
 sole #0D47A1:
  (13,30)                         ← 뒷굽
 lace detail #FFFFFF:
  (12,29)                         ← 끈 1점
 outline #1565C0: (10,29)(14,29)(10,30)(13,30 은 sole 자체)

오른발: 거울 대칭 (col 18-21 에)
```

### shoes/boots (갈색 부츠)

```
upper base #5D4037:
 (11,28)(12,28)(13,28)           ← 부츠는 rows 28 까지 올라옴 (긴 부츠)
 (11,29)(12,29)(13,29)
 (11,30)(12,30)(13,30)

shaft shadow #3E2723:
 (13,28)(13,29)                   ← 뒤쪽 세로

buckle/strap #D7A441:
 (11,28)(12,28)                   ← 부츠 상단 장식 밴드

sole #1B0E06:
 (10,30)(11,30 이미 base → overwrite)  → 실제로는 sole 을 base 아래에 깔기
 권장: sole 을 먼저 (11,30)(12,30)(13,30) 으로 그리고 그 위에 upper(29) 얹기

outline #1B0E06: 갑피 외곽

오른발 거울 대칭.
```

### shoes/heels (분홍 힐)

```
upper base #E91E63:
 (12,29)(13,29)                   ← 갑피 좁게 2px

heel spike (가는 굽):
 (13,30)                           ← 힐 1px 뒤 (발레처럼)

toe-box:
 base: (11,29)(12,30)              ← 앞코 살짝 노출

sole #880E4F: (11,30)(12,30)(13,30)
highlight #F48FB1: (12,29)
outline #880E4F

오른발 대칭 — 힐은 (18,30) 위치.
```

### shoes/loafers (검정 로퍼)

```
upper base #37474F:
 (11,29)(12,29)(13,29)

saddle strap (가로띠):
 #546E7A: (12,29)                 ← 로퍼 특유의 가로 디테일

toe-box glossy:
 highlight #78909C: (11,29)

sole #1C2A31: (11,30)(12,30)(13,30)
outline #0F1A20

오른발 대칭.
```

### shoes/sandals (노랑 샌들)

```
strap crisscross (X자 끈):
 base #D4A017:
  (11,29)(13,29)                   ← 양옆 스트랩 2점
 accent #FFEB3B:
  (12,29)                           ← 가운데 버클

sole brown:
 #8D6E63: (11,30)(12,30)(13,30)

발가락 노출 (skin tone):
 (10,30) 는 skin 유지                ← 샌들 앞이 열려있음

outline #6D5F10

오른발 대칭.
```

### shoes/golden_shoes (황금 신발 EPIC)

```
sneakers 구조에 gold 톤:
 upper base #FFD700: (11,29)(12,29)(13,29)
 toe-box #FFF59D: (11,30)(12,30)
 sole #B8860B: (13,30)
 sparkle #FFFFFF: (12,29)
 outline #8B6914

+ EPIC 셰이머 별도 추가 (§14)
```

## Accessory Scaling Rules

`accessory_renderer.dart` 의 기존 accessory (duck_watergun, laptop 등) 는 16×16 좌표계로 작성됨. 32×32 로 옮기려면 직접 재작성이 필요하지만, 본 문서는 **좌표 offset 규칙** 만 제공해 점진적 이전 가능하게 한다.

### Coordinate Mapping

```
// 각 pixel 을 2x2 로 확장 + 위치 조정
// x_new = x_old * 2 - 1     (16-grid 의 (x) → 32-grid 의 (2x-1, 2x))
// y_new = y_old * 2 + 4     (대략 얼굴/가슴 기준을 새 캔버스에 맞춤)
// size: 기존 1 pixel → 2×2 block

void remapPixel(int xOld, int yOld, Canvas canvas, double px, Color c) {
  final xNew = xOld * 2 - 1;
  final yNew = yOld * 2 + 4;
  // 2x2 block
  _drawPixel(canvas, paint, xNew, yNew, px);
  _drawPixel(canvas, paint, xNew + 1, yNew, px);
  _drawPixel(canvas, paint, xNew, yNew + 1, px);
  _drawPixel(canvas, paint, xNew + 1, yNew + 1, px);
}
```

이 방식은 픽셀이 2×2 로 확대되어 투박해지므로, **1차 릴리스** 용 임시 변환. 2차 릴리스에서는 각 accessory 를 네이티브 32×32 로 재작성 권장.

### Native 32×32 권장 영역

| Accessory | 권장 bbox (32×32) | Hand pos (기존 유지) |
|-----------|-------------------|---------------------|
| duck_watergun | (8,19)-(12,22) 왼손에 들림 | left arm 앞 |
| laptop | (11,20)-(20,24) 양손으로 | 무릎 위 |
| earphone | (8,7)-(10,12)(21,7)-(23,12) | 머리 옆 |

실제 좌표는 accessory 별 후속 디자인 문서로 분리.

## EPIC Shimmer / Sparkle (32×32 포트)

기존 `_drawSparkles` 는 16×16 기준 6개 pixel 위치였음. 32×32 로 확장:

```dart
final sparklePositions = [
  [3, 3], [28, 3],     // 머리 양옆 2 point
  [1, 15], [30, 14],    // 어깨 양옆
  [5, 25], [26, 27],    // 허리 주변
  [15, 1], [14, 31],    // 중앙 위아래
];

// 각 sparkle 은 3x3 cross 패턴으로 크기 up:
//    · X ·
//    X X X
//    · X ·
// (기존 1-pixel 에서 5-pixel star 로 확장)
```

Crown gold shimmer 좌표 (기존 3 pixel → 5 pixel) 교체:
```
[(14,0)(15,0)(16,0)(17,0)(18,0)]   ← 왕관 5-point 꼭대기 금빛
```

Shimmer 애니메이션 값 (shimmerValue, accessoryAnimValue) 은 `_PixelCharacterPainter` 생성자 파라미터 유지, `_CharacterAvatarState` 의 AnimationController 도 그대로.

## Integration with MiniroomScene

`MiniroomScene` (`app/lib/core/widgets/miniroom_scene.dart` — 아직 미구현, `miniroom-cyworld.md` 참조) 는 `CharacterAvatar(size: 110dp)` 로 캐릭터를 배치한다.

| 치수 | 계산 | 결과 |
|------|------|------|
| 캐릭터 위젯 크기 | 110dp | 110dp × 110dp |
| 논리 픽셀 크기 | 110 / 32 | ≈ 3.44 dp/pixel |
| 방 그리드 픽셀 크기 | 방 width / 32 (가로 기준) | 방과 동일 스케일 |

**시각적 합일**: 방 그리드(32×24) 와 캐릭터 그리드(32×32) 가 같은 3~4dp/pixel 로 렌더되어, 방 안의 가구·벽 타일과 캐릭터 파츠가 동일 해상도로 보인다. 이것이 미니룸 + 미니미 통합 감성의 핵심.

**안티앨리어스 OFF 필수**: `Paint..isAntiAlias = false..filterQuality = FilterQuality.none` 유지. 도트감 보존.

## Responsive Sizing

| Context | Character size | 픽셀 sharpness |
|---------|---------------|---------------|
| 상점 썸네일 | 40dp | 낮음 (blur) — 권장 최소 |
| 인벤토리 프리뷰 | 80dp | 보통 |
| 미니룸 내 | 110dp | 양호 |
| 캐릭터 커스터마이즈 | 160dp | 최고 |
| 사진 스탬프 | 64dp ~ 128dp | paintCharacterIntoCanvas |

**40dp 미만에서는 가독성 급락** — 아이템 프리뷰에서는 아이콘 중심(item_icon_painter) 으로 대체 권장.

## Backward Compatibility

**유지 (변경 금지):**
- `CharacterAvatar` Stateful 위젯의 props (`character`, `size`, `showEffect`)
- `CharacterData` 필드 (`skinTone`, `hairStyle`, `eyeStyle`, `hat.assetKey`, `top.assetKey`, `bottom.assetKey`, `shoes.assetKey`, `accessory.assetKey`, `*.rarity`)
- `paintCharacterIntoCanvas(canvas, character: data, dst: rect)` 시그니처
- EPIC shimmer 애니메이션 컨트롤러 / accessory 애니메이션 컨트롤러
- `_hasEpicItem`, `_hasAnimatedAccessory` 헬퍼 로직

**내부 교체:**
- `_PixelCharacterPainter` 의 모든 `_draw*` 메서드 본문
- `final px = size.width / 16.0` → `final px = size.width / 32.0`
- 색상 상수 (`_hairBrown`, `_defaultShirt` 등) → `CharacterPalette` class 로 통합
- `_getHairPattern`, `_getEyePattern` return 좌표값 전면 교체

**옵션: Feature Flag (권장)**
1차 릴리스에서는 `CharacterAvatar` 에 `bool useHighRes = true` 파라미터를 추가해 토글 가능하게 함 — 롤백 용이. 2차 릴리스에서 제거.

## Dark Mode

방 씬 자체가 "조명 켜진 실내" 로 다크모드에서도 밝은 색상 유지 (`miniroom-cyworld.md:187`). 캐릭터도 동일 팔레트 사용. 단, 아웃라인은 살짝 강화:

- Light mode: outline = base L − 0.35
- Dark mode: outline = base L − 0.40 (방 배경과의 구분력 보강)

구현: `Theme.of(context).brightness` 체크 후 파츠별 outline color 선택.

## Migration Plan (front 워크트리 용)

프론트 워크트리에서 본 문서를 참조해 아래 순서로 구현 권장:

1. `CharacterPalette` class 추가 (별도 파일 `character_palette.dart` 또는 기존 파일 상단)
2. `_paintLayer` 헬퍼 메서드 추가
3. `_drawBase` 를 32×32 좌표로 재작성 — skin / hair outline / hair base / hair highlight / eyes / mouth / blush 순차
4. `_drawBody`, `_drawLegs`, `_drawShoes` 기본 (equipment 없을 때) 재작성
5. `_drawHatEquipment` 6종 순차 재작성
6. `_drawTopEquipment` 7종 순차 재작성
7. `_drawBottomEquipment` 6종 순차 재작성
8. `_drawShoesEquipment` 6종 순차 재작성
9. `accessory_renderer.dart` — §13 의 remap 규칙으로 임시 확장 (2차 릴리스에서 네이티브 재작성)
10. `_drawSparkles` 좌표 32×32 로 교체
11. iOS 시뮬레이터에서 `my_room_screen` + 상점 프리뷰 + 사진 스탬프 3가지 경로 검증

각 단계 후 `flutter build ios --simulator` 가 통과해야 진행.

## Verification Checklist (QA용)

프론트 구현 후 반드시 확인:

- [ ] **내 방 화면**: 미니룸 + 캐릭터 렌더 시 방 그리드 와 캐릭터 그리드가 같은 스케일로 보임 (타일 / 픽셀 크기 통일)
- [ ] **얼굴 인식성**: 110dp 크기에서 눈·코·입·볼이 명확히 구분됨
- [ ] **표정 구분**: round/sharp/sleepy 3가지 눈 + smile/smirk/neutral 3가지 입 교차 조합 9가지가 시각적으로 구분됨
- [ ] **헤어 구분**: short/long/curly 3 스타일이 한눈에 구분됨
- [ ] **의상 6 slot × 3 rarity** 조합 렌더 검증 — EPIC 아이템에서 shimmer / sparkle 이 32×32 캔버스 외곽에 정상 표시
- [ ] **애니메이션**: duck_watergun, laptop 등 accessory anim 이 위치 어긋남 없이 재생
- [ ] **사진 스탬프**: `paintCharacterIntoCanvas` 로 캡쳐한 이미지가 깨지지 않고 선명
- [ ] **다크모드**: 방 + 캐릭터가 모두 밝게 유지되고 외곽선 구분됨
- [ ] **반응형**: 40/80/110/160 dp 에서 각 경로 (상점/인벤토리/미니룸/커스터마이즈) 가독성 양호
- [ ] **iOS Simulator 빌드**: `flutter build ios --simulator` 통과
- [ ] **Visual smoke**: 시뮬레이터에서 캐릭터 화면 총 10회 이상 탭 이동하며 렌더 깨짐 없음

## Cyworld Reference Notes

- **비율**: 원조 미니미도 2.3-2.5 heads tall chibi. 머리가 몸보다 큰 귀여움.
- **눈**: 크고 동글, white highlight 1-2 px 필수. 동공은 검정보다 따뜻한 짙은 갈/검정.
- **볼 홍조**: 분홍 2×1 이 아이덴티티.
- **의상 아웃라인**: 단색 검정 ❌. 각 옷 base 색의 darker tone ⭕.
- **3-tone ramp**: 음영 1 + base + 하이라이트 1 은 Y2K 픽셀아트의 공식. 이 문서에서도 준수.
- **광원**: 왼쪽 위. 방의 창문과 일치.
- **비대칭**: beret 기울기, accessory 한손 들기 정도. 얼굴·몸·다리는 대칭.
- **전면 뷰**: Cyworld 미니미는 frontal view + 자연스러운 기본 자세. 본 문서도 frontal.

## Future (P1+)

- **Hair color** 필드 추가 — `hairColorKey: 'brown' | 'black' | 'blonde' | 'pink'` 로 4종 팔레트 확장
- **Pose 변형** — `pose: 'idle' | 'waving' | 'sitting'` 로 포즈 다양화 (현재는 idle 고정)
- **Skin tone 확장** — 현재 3 tone (fair/light/dark) → 5 tone 세분화
- **Facial expression 상태** — streak / shield 활성에 따라 자동 표정 변경 (현재는 user setting 고정)
- **Accessory 네이티브 32×32 재작성** — §13 의 remap 은 임시. 2차 릴리스에서 각 accessory 당 디자인 문서 분리 작성
- **Outfit preset** — 아이템 조합 저장/불러오기 (캐릭터 레이어링 시스템이 안정화되면 가능)

## Related

- `docs/design/miniroom-cyworld.md` — 방 디자인 + 캐릭터 통합 지점
- `docs/character-system-spec.md` — 64×64 에셋 계약 + 5-slot 커스터마이징 전체 사양 (변경 없음)
- `app/lib/core/widgets/character_avatar.dart` — 본 문서의 구현 대상
- `app/lib/core/widgets/accessory_renderer.dart` — §13 대상
- `app/lib/features/character/models/character_data.dart` — 필드 계약 (변경 없음)
- `docs/design/room-decoration.md` — P2 캐릭터·룸 꾸미기 확장 (본 문서와 호환)
