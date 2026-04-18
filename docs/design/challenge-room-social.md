---
slug: challenge-room-social
status: ready
created: 2026-04-18
area: front
depends-on: miniroom-cyworld
---

# Challenge Room — Cyworld Style Social Miniroom

## Overview

챌린지 방(ChallengeSpaceScreen) 상단에 싸이월드 미니룸 스타일의 공유 방을 추가한다. 챌린지 멤버들의 캐릭터가 한 방에 모여 있고, 인증 상태에 따라 캐릭터가 다르게 반응하며, 터치로 콕 찌르기 등 상호작용이 가능한 소셜 공간.

기존 캘린더/멤버 리스트는 방 아래에 유지하되, "방에 모인 캐릭터들"이 챌린지 방의 첫인상이 된다.

## Design Concept

```
 ┌──────────────────────────────────────┐
 │  천장 몰딩        ✨ 챌린지제목 ✨     │
 │  ┌───────┐  🕐  ┌─────┐ ┌─────────┐│
 │  │ 창문  │      │달력판│ │ 게시판   ││ ← 뒷벽
 │  │ (하늘) │      │04/18│ │ 📌📝   ││
 │  └───────┘      └─────┘ └─────────┘│
 │═════════════════════════════════════│ ← 걸레받이
 │                                     │
 │   😊    😴    🎉    😤             │ ← 바닥 (멤버 캐릭터들)
 │  철수   영희   민수   지은           │
 │  (인증✓) (미인증) (인증✓) (미인증)    │
 │         ╭────────────╮             │
 │         │   소파/러그  │             │
 │         ╰────────────╯             │
 └──────────────────────────────────────┘
       [오늘 3/5명 인증 완료]  (하단 요약)
```

## Core Interactions

### 1. 캐릭터 상태별 표현

| 인증 상태 | 캐릭터 비주얼 | 위치 |
|-----------|-------------|------|
| 인증 완료 | 활발한 포즈 + 반짝이 이펙트 + ✓ 배지 | 방 앞쪽 (바닥 위) |
| 미인증 | 졸고 있는 포즈 (기울어짐 + ZZZ) | 방 뒤쪽 (벽 근처) |
| 방장 | 왕관 이펙트 | 일반 위치 |

**졸고 있는 포즈 구현:**
- 캐릭터를 5도 기울임 (Transform.rotate)
- 머리 위에 "Z z z" 텍스트 floating 애니메이션 (opacity 0.3→1.0, y drift)
- 전체 색상 약간 desaturate (ColorFiltered, saturation 0.6)

**인증 완료 포즈:**
- 기존 TappableCharacter 탭 반응 활성
- 머리 위에 작은 ✓ 아이콘 (초록색 원 안에 체크)
- 주기적 미세 bounce 애니메이션 (2초마다 살짝 점프)

### 2. 터치 상호작용

| 터치 대상 | 동작 |
|-----------|------|
| 내 캐릭터 (인증 완료) | TappableCharacter 6종 반응 (기존) |
| 내 캐릭터 (미인증) | "인증하러 가기!" 토스트 → CreateVerificationScreen으로 이동 |
| 다른 멤버 캐릭터 (인증 완료) | 캐릭터가 손 흔들기 반응 + 말풍선 "👋" |
| 다른 멤버 캐릭터 (미인증) | **콕 찌르기!** 바텀시트 → 기존 nudge API 호출 |
| 방 가구 (게시판) | 오늘의 인증 현황 팝업 |
| 방 가구 (달력판) | 캘린더 섹션으로 스크롤 |

### 3. 전원 인증 시 축하 연출

모든 멤버가 인증 완료하면:
- 방 전체에 반짝이 파티클 효과 (3초)
- 캐릭터 전원 동시 점프 애니메이션
- 시즌 아이콘이 방 중앙에 크게 표시 (🌸/🌿/🍁/❄️)
- 천장에 축하 배너 표시: "🎉 오늘 전원 인증 완료!"

## Room Layout (32x24 Grid)

미니룸과 동일한 32x24 픽셀 그리드 사용. 가구 배치는 챌린지 방 맥락에 맞게 변형.

### 벽 요소 (rows 0-12)

| Element | Grid Position | Description |
|---------|---------------|-------------|
| Ceiling molding | rows 0-1 | 장식 라인 + 챌린지 제목 오버레이 |
| Back wall | rows 2-11 | 방장의 배경색으로 틴트 |
| Window | cols 2-8, rows 3-8 | 하늘색 유리 + 구름 (미니룸과 동일) |
| Mini calendar | cols 12-16, rows 4-8 | 오늘 날짜 표시하는 작은 달력판 |
| Bulletin board | cols 20-30, rows 3-9 | 코르크 보드 + 핀 + 메모지 (인증 현황) |
| Clock | cols 17-19, rows 3-5 | 시계 (미니룸과 동일) |
| Baseboard | row 12 | 벽-바닥 경계 |

### 바닥 요소 (rows 12-23)

| Element | Grid Position | Description |
|---------|---------------|-------------|
| Floor | rows 12-23 | 나무 바닥 패턴 (미니룸 체커보드와 차별화) |
| Sofa/Rug | cols 8-24, rows 17-22 | 큰 소파 또는 원형 러그 (모임 공간) |
| Character slots | dynamic | 멤버 수에 따라 자동 배치 |

### 캐릭터 배치 알고리즘

멤버 수(2-6명)에 따라 방 안에서 자연스럽게 분산 배치:

```
2명: 좌우 대칭
  ┌─────────────┐
  │   A     B   │
  └─────────────┘

3명: 삼각형
  ┌─────────────┐
  │      A      │
  │   B     C   │
  └─────────────┘

4명: 반원형
  ┌─────────────┐
  │   A     B   │
  │  C       D  │
  └─────────────┘

5명: W형
  ┌─────────────┐
  │  A   B   C  │
  │    D   E    │
  └─────────────┘

6명: 2x3 그리드
  ┌─────────────┐
  │  A  B  C    │
  │  D  E  F    │
  └─────────────┘
```

**배치 규칙:**
- 인증 완료 멤버는 앞쪽 row (바닥 가까이)
- 미인증 멤버는 뒷쪽 row (벽 가까이, 졸고 있음)
- 방장은 항상 첫 번째 슬롯
- 본인 캐릭터는 약간 크게 (1.1x scale)

**좌표 계산:**
```dart
List<Offset> _calcPositions(int count, Size roomSize) {
  // 사용 가능 영역: 바닥 rows 13-22
  // 좌우 패딩: 10%
  // y 범위: roomHeight * 0.55 ~ 0.85
  // x 범위: roomWidth * 0.1 ~ 0.9
  // 멤버 수에 따라 프리셋 좌표 반환
}
```

## Color Palette

미니룸(`miniroom-cyworld.md`)의 MiniroomColors 재사용 + 챌린지 전용 추가:

```dart
class ChallengeRoomColors {
  // 미니룸 색상 재사용
  // + 챌린지 전용

  // Bulletin board
  static const corkBoard = Color(0xFFD7CCC8);     // 코르크 보드
  static const corkBoardDark = Color(0xFFBCAAA4);
  static const pinRed = Color(0xFFE57373);          // 빨간 핀
  static const pinYellow = Color(0xFFFFF176);       // 노란 핀
  static const memoWhite = Color(0xFFFFFDE7);       // 메모지
  static const memoBlue = Color(0xFFE3F2FD);        // 파란 메모지

  // Mini calendar
  static const calendarBg = Color(0xFFFFFDE7);      // 달력 배경
  static const calendarRed = Color(0xFFEF5350);     // 오늘 날짜 강조
  static const calendarText = Color(0xFF5D4037);

  // Floor (wood pattern, different from miniroom checkerboard)
  static const woodFloorLight = Color(0xFFE8D5B7);
  static const woodFloorDark = Color(0xFFD4B896);
  static const woodFloorGrain = Color(0xFFC9A882);

  // Status indicators
  static const verifiedGreen = Color(0xFF66BB6A);
  static const unverifiedGray = Color(0xFFBDBDBD);
  static const sleepyBlue = Color(0xFF90CAF9);      // ZZZ 색상

  // Celebration
  static const partyGold = Color(0xFFFFD54F);
  static const partyPink = Color(0xFFF48FB1);
  static const sparkle = Color(0xFFFFFFFF);
}
```

**벽 틴팅:** 방장(creator)의 `backgroundColor`를 30% blend. 개인 방과 구분되는 "공유 공간" 느낌.

## Architecture

### New Files

1. **`app/lib/core/widgets/challenge_room_scene.dart`** (~600-700 lines)
   - `ChallengeRoomScene` — StatefulWidget (축하 애니메이션 컨트롤)
   - `_ChallengeRoomBackgroundPainter` — CustomPainter (벽, 바닥, 가구)
   - `_BulletinBoardPainter` — CustomPainter (게시판 디테일)
   - `ChallengeRoomColors` — 색상 상수

2. **`app/lib/features/challenge_space/widgets/room_character.dart`** (~300 lines)
   - `RoomCharacter` — StatefulWidget (개별 캐릭터 + 상태 표현)
   - 인증 상태별 비주얼 (활발/졸고 있음)
   - 터치 핸들러 (콕 찌르기, 인증하기, 손 흔들기)
   - 닉네임 라벨 + 상태 배지
   - ZZZ/sparkle 애니메이션

3. **`app/lib/features/challenge_space/widgets/celebration_overlay.dart`** (~150 lines)
   - `CelebrationOverlay` — 전원 인증 시 파티클 효과
   - 시즌 아이콘 확대 표시
   - 축하 배너 텍스트

### Modified Files

4. **`app/lib/features/challenge_space/screens/challenge_space_screen.dart`**
   - 현재 구조 상단에 `ChallengeRoomScene` 추가
   - CalendarMember 데이터를 room scene에 전달
   - 오늘 인증 상태 데이터를 room characters에 매핑

## Data Flow

```
ChallengeSpaceScreen
  ├─ challengeDetailProvider → 챌린지 제목, 방장 정보
  ├─ calendarProvider(year, month) → 오늘 날짜의 verifiedMembers
  ├─ authStateProvider → 내 ID
  └─ ChallengeRoomScene
       ├─ members: List<CalendarMember> (캐릭터 데이터 포함)
       ├─ verifiedMemberIds: Set<String> (오늘 인증한 멤버 ID)
       ├─ myId: String
       ├─ creatorId: String (방장)
       ├─ challengeTitle: String
       ├─ onNudge: (memberId) → 기존 nudge API
       ├─ onVerify: () → CreateVerificationScreen 이동
       └─ allCompleted: bool → 축하 연출 트리거
```

### 기존 API 그대로 활용

새 API 없음. CalendarData의 `members`에 이미 `CharacterData?`가 포함되어 있고, `DayEntry.verifiedMembers`로 오늘 인증 여부 판별 가능.

```dart
// 오늘 날짜의 인증 멤버 추출
final today = effectiveToday(DateTime.now(), detail.dayCutoffHour);
final todayEntry = calendarData.days.firstWhereOrNull(
  (d) => d.date == today.toIso8601String().substring(0, 10),
);
final verifiedIds = todayEntry?.verifiedMembers.toSet() ?? {};
final allCompleted = todayEntry?.allCompleted ?? false;
```

## Screen Layout (수정 후)

```
ChallengeSpaceScreen (ScrollView)
│
├─ ChallengeRoomScene (h: 280)          ← 신규 추가
│   ├─ Room background (wall + floor + furniture)
│   ├─ Characters (positioned by member count)
│   ├─ Celebration overlay (if allCompleted)
│   └─ Today summary badge ("3/5명 인증")
│
├─ NudgeBanner                           ← 기존 유지
├─ Month navigator                       ← 기존 유지
├─ CalendarGrid                          ← 기존 유지
├─ Today verification section            ← 기존 유지
└─ MemberNudgeList                       ← 기존 유지 (방 안 캐릭터와 중복이지만
                                            세부 정보 + 넛지 확인용으로 유지)
```

## Character Animations

### 졸고 있는 캐릭터 (미인증)

```dart
// ZZZ floating animation
AnimatedBuilder(
  animation: _zzzController,  // 2s repeat
  builder: (_, __) => Stack(
    children: [
      // Character body (tilted 5deg, desaturated)
      Transform.rotate(
        angle: 0.087,  // ~5 degrees
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix(_desaturateMatrix(0.6)),
          child: CharacterAvatar(character: member.character, size: charSize),
        ),
      ),
      // ZZZ text
      Positioned(
        right: -5,
        top: -10,
        child: Opacity(
          opacity: _zzzAnimation.value,
          child: Transform.translate(
            offset: Offset(0, -8 * _zzzAnimation.value),
            child: Text('Z z z',
              style: TextStyle(
                fontSize: 10,
                color: ChallengeRoomColors.sleepyBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    ],
  ),
)
```

### 인증 완료 캐릭터

```dart
// Periodic micro-bounce
AnimatedBuilder(
  animation: _bounceController,  // 3s repeat
  builder: (_, child) => Transform.translate(
    offset: Offset(0, -3 * sin(_bounceAnimation.value * pi)),
    child: child,
  ),
  child: Stack(
    children: [
      TappableCharacter(
        child: CharacterAvatar(character: member.character, size: charSize),
      ),
      // Verified badge
      Positioned(
        right: -2,
        top: -2,
        child: Container(
          width: 16, height: 16,
          decoration: BoxDecoration(
            color: ChallengeRoomColors.verifiedGreen,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Icon(Icons.check, size: 10, color: Colors.white),
        ),
      ),
    ],
  ),
)
```

### 손 흔들기 반응 (다른 멤버 인증완료 터치)

```dart
// Wave reaction: rotate + move hand sprite
// 500ms duration, slight rotation + scale pop
SequenceAnimation:
  0-150ms: scale 1.0 → 1.1
  150-350ms: rotate -0.1 → 0.1 → -0.1 rad (흔들기)
  350-500ms: scale 1.1 → 1.0
// + speech bubble "👋" fading in/out above head
```

### 전원 인증 축하

```dart
// CelebrationOverlay: 3-second sequence
// Phase 1 (0-1s): All characters jump simultaneously
//   - Each character: translateY -20 → 0 (sine curve)
// Phase 2 (1-2s): Season icon scales in at room center
//   - scale 0 → 1.5 → 1.0 with elastic curve
//   - glow effect behind icon
// Phase 3 (2-3s): Particle confetti
//   - 20-30 small colored circles falling from top
//   - colors: partyGold, partyPink, verifiedGreen, skyBlue
//   - random x positions, gravity-based y movement
// Banner: "🎉 오늘 전원 인증 완료!" at ceiling, fade in at 0.5s
```

## Room Furniture Details

### Bulletin Board (게시판)

코르크 보드 + 핀 + 메모지로 인증 현황을 시각적으로 표현:

```
┌──────────────┐
│ 📌 오늘현황  │
│ ✓철수 ✓민수 │
│  영희  지은  │  ← 미인증은 핀 없이 흐릿하게
│ 📌         📌│
└──────────────┘
```

- 나무 프레임 (woodDark)
- 코르크 배경 (corkBoard)
- 인증 완료 멤버: 빨간 핀 + 밝은 메모지
- 미인증 멤버: 핀 없이 흐릿한 메모지
- 터치 시 오늘 인증 현황 상세 팝업

### Mini Calendar (달력판)

벽에 걸린 작은 달력:

```
┌────────┐
│ 4월    │
│   [18] │  ← 오늘 날짜 빨간 동그라미
│        │
└────────┘
```

- 흰 배경 (calendarBg)
- 오늘 날짜만 빨간 원으로 강조
- 터치 시 캘린더 섹션으로 스크롤

### Sofa / Gathering Area

방 중앙 하단에 반원형 소파 또는 큰 원형 러그:

- 캐릭터들이 이 주변에 모여 있는 느낌
- 미니룸의 러그와 유사하되 더 크고 사회적
- 색상: 챌린지 카테고리에 따라 변형 가능 (운동=초록, 공부=파랑, 습관=핑크)

## Responsive

- Screen height < 600dp: room 220dp, character 45dp
- Screen height >= 600dp: room 280dp, character 55dp
- 멤버 6명 초과 시: 캐릭터 크기 축소 (40dp), 3x3 배치

## Nickname Labels

각 캐릭터 아래 닉네임 표시:
- 폰트 크기: 9dp
- 본인: primary color + bold
- 방장: 이름 앞에 👑 작은 아이콘
- 글자 수 4자 초과 시 말줄임

## Edge Cases

| Case | Handling |
|------|----------|
| 멤버 1명 (혼자) | 캐릭터 중앙 배치, "함께할 친구를 초대하세요!" 말풍선 |
| 멤버 7명+ | 캐릭터 축소 (40dp), 최대 8명까지 표시, 초과 시 "+N" 배지 |
| 챌린지 완료 상태 | 모든 캐릭터 축하 포즈 고정, 트로피 가구 추가 |
| 캐릭터 데이터 없음 | 기본 캐릭터 (장비 없음) 표시 |
| 오늘 날짜 계산 | day_cutoff_hour 반영하여 effective today 사용 |

## Implementation Priority

이 디자인은 front 워크트리에서 구현:

1. **Phase 1**: ChallengeRoomScene (방 배경 + 정적 캐릭터 배치)
2. **Phase 2**: RoomCharacter (인증 상태별 비주얼 + 터치 상호작용)
3. **Phase 3**: CelebrationOverlay (전원 인증 축하 연출)
4. **Phase 4**: 가구 인터랙션 (게시판, 달력판 터치)

## Related

- `docs/design/miniroom-cyworld.md` — 개인 미니룸 디자인 (공유 색상/패턴)
- `app/lib/features/challenge_space/screens/challenge_space_screen.dart` — 현재 챌린지 방
- `app/lib/core/widgets/character_avatar.dart` — 픽셀아트 캐릭터 렌더러
- `app/lib/core/widgets/tappable_character.dart` — 탭 반응 위젯
- `app/lib/features/challenge_space/widgets/member_nudge_list.dart` — 기존 멤버 리스트+넛지
