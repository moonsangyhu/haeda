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
| 캘린더 **오늘 셀** (내가 미인증) | `CreateVerificationScreen` 으로 이동 (= 인증 진입) |
| 캘린더 **오늘 셀** (내가 인증 완료) | 오늘 인증 상세 리스트 (`/verifications/{date}`) |
| 캘린더 **과거 셀** | 해당 날짜 인증 상세 리스트 (기존) |
| 캐릭터 방 좌하단 **"전체 멤버 보기" 버튼** | `MembersBottomSheet` 오픈 (멤버 리스트 + 콕찌르기) |

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
   - 상단에 `ChallengeRoomScene` 추가
   - CalendarMember 데이터를 room scene에 전달
   - 오늘 인증 상태 데이터를 room characters에 매핑
   - **(2026-04-19 개정)** `_TodaySection`(인증하기 버튼) 위젯 제거
   - **(2026-04-19 개정)** `_MemberSection` / `MemberNudgeList` inline 노출 제거 — `MembersBottomSheet` 진입은 scene 좌하단 트리거 버튼으로 일원화
   - **(2026-04-19 개정)** `_onDayTap` 분기 추가: 오늘 셀 + 미인증 → `/challenges/{id}/verify` 직접 진입

5. **`app/lib/features/challenge_space/widgets/calendar_day_cell.dart`** (개정)
   - 오늘 셀 외곽 2px primary 테두리 + 인증 상태별 좌상단 마커 (✓/⏳/✗)
   - `isToday`, `isMineVerified`, `isPast` 분기 추가

6. **`app/lib/features/challenge_space/widgets/member_nudge_list.dart`** (재사용)
   - `_MemberRow` 는 그대로 두고, 시트 컨테이너만 신규로 작성 (다음 항목)

### New Files (2026-04-19 개정으로 추가)

7. **`app/lib/features/challenge_space/widgets/members_bottom_sheet.dart`** (~120 lines)
   - `MembersBottomSheet` — `showModalBottomSheet` 컨테이너
   - 헤더 (챌린지원 + N/M 인증) + `MemberNudgeList`(`_MemberRow` 재사용) + 닫기 버튼
   - 정렬 (미인증 우선) + 콕찌르기 액션 (기존 API 그대로)

8. **`app/lib/core/widgets/challenge_room_scene.dart` 내 신규 위젯** `_AllMembersTriggerButton`
   - 좌하단 캡슐 버튼 (`Positioned(left: 8, bottom: 8)`)
   - `verifiedCount / totalCount` 라벨 + 미인증 있을 때 빨간 점
   - 탭 → `_AllMembersTriggerButton` 부모(scene)에서 외부로 전달된 `onShowMembers()` 호출
   - scene 자체는 시트 dispatch 모르게 — 콜백만 받음 (테스트 용이)

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

## Screen Layout (2026-04-19 개정)

스크롤이 길어 사용자 경험이 떨어지던 문제를 해결하기 위해 하단 두 섹션을 정리했다:

- ❌ **`_TodaySection` (인증하기 버튼) 제거** — 캘린더 오늘 셀 탭으로 동일 진입 가능
- ❌ **`_MemberSection` / `MemberNudgeList` inline 제거** — `MembersBottomSheet` 로 이동, 캐릭터 방 좌하단 트리거 버튼으로 진입
- ✅ **캘린더 오늘 셀 시각 강화** — 내가 인증했는지 한눈에 식별 (§Today Cell Highlight 참고)
- ✅ **`SpeechInputBar`** — 카톡식 한 줄 입력 바 (`challenge-room-speech.md` 참고)

```
ChallengeSpaceScreen (ScrollView)
│
├─ ChallengeRoomScene (h: 280)
│   ├─ Room background (wall + floor + furniture)
│   ├─ Characters (positioned by member count)
│   ├─ Celebration overlay (if allCompleted)
│   ├─ Today summary badge ("3/5명 인증")        ← 우상단
│   └─ "전체 멤버 보기" trigger button            ← 좌하단 (신규)
│
├─ SpeechInputBar (h: 56-84)                  ← scene 직하부 (challenge-room-speech.md)
├─ NudgeBanner                                ← 기존 유지
├─ Month navigator                            ← 기존 유지
├─ CalendarGrid                               ← 오늘 셀 강조 적용 (§Today Cell Highlight)
└─ (bottom padding 24)

[On demand]
└─ MembersBottomSheet                         ← 좌하단 버튼 → 모달 시트
```

스크롤 길이는 약 1.5 화면 분량으로 단축. 핵심 지표(오늘 인증 여부)는 캘린더 셀에서 즉시 인지, 멤버 상호작용은 캐릭터 방 또는 시트로 이원화.

## Today Cell Highlight (캘린더)

캘린더 그리드에서 **오늘 셀**은 다른 셀과 명확히 구분되어야 하며, **내가 인증했는지 안 했는지**를 즉시 식별 가능해야 한다.

### 시각 사양

| 상태 | 셀 시각 |
|------|--------|
| 오늘 + **내가 미인증** | 2px primary color 외곽 테두리 + 좌상단 작은 ⏳ 마커 + 셀 내부 옅은 primary tint (`primary.withOpacity(0.06)`) |
| 오늘 + **내가 인증 완료** | 2px primary color 외곽 테두리 + 좌상단 작은 ✓ 마커 (verifiedGreen 배경의 흰 체크) + 인증한 멤버 썸네일/시즌 아이콘 (기존) |
| 오늘 + 내가 인증 + **전원 인증** | 2px primary color 테두리 + 시즌 아이콘 크게 + 좌상단 ✓ 마커 |
| 과거 + 내가 인증 | 좌상단 ✓ 마커 (작은 회색) + 기존 썸네일 |
| 과거 + 내가 미인증 | 좌상단 ✗ 마커 (옅은 회색, 작음) — 단, 미인증 셀이 너무 빨갛게 보이지 않게 절제 |
| 미래 | 회색 텍스트, 마커 없음 |

### 마커 디자인

- 위치: 셀 좌상단 `(2dp, 2dp)` offset
- 크기: 12×12dp
- 모양: `BoxDecoration(shape: BoxShape.circle, color: ...)` + `Icon(size: 8)`
- ✓: `verifiedGreen` 배경 + 흰 체크
- ⏳: `unverifiedGray` 배경 + 흰 모래시계
- ✗: 투명 배경 + `Color(0xFFBDBDBD)` X 아이콘 (과거만)

### "오늘" 셀 외곽 테두리

- 평소 셀은 1px hairline border (`outline.withOpacity(0.1)`)
- 오늘 셀: 2px solid `primary` border + 8dp inner radius
- 전원 인증 시즌 아이콘이 있어도 테두리 우선 — z-order 최상위

### 탭 동작 변경

| 탭 대상 | 동작 |
|---------|------|
| 오늘 셀 (내가 미인증) | **`CreateVerificationScreen` 직접 진입** (이전 `_TodaySection` 의 인증하기 버튼 역할 흡수) |
| 오늘 셀 (내가 인증 완료) | `/verifications/{date}` 인증 상세 리스트 |
| 과거 셀 (인증 존재) | `/verifications/{date}` 인증 상세 리스트 (기존) |
| 과거 셀 (인증 없음) | "아직 인증한 사람이 없어요" 토스트 (기존 dialog 대체) |
| 미래 셀 | 기존 dialog 유지 |
| 챌린지 시작 전 셀 | 기존 dialog 유지 |

탭 라우팅 분기는 `calendar_day_cell.dart` 또는 `challenge_space_screen.dart` `_onDayTap` 에서 `effectiveToday` + `verifiedMembers.contains(myId)` 로 판단.

## Members Bottom Sheet

캐릭터 방 좌하단 **"전체 멤버 보기"** 버튼 → 바텀시트로 멤버 리스트 표시.

### 트리거 버튼

```
┌──────────────────────────────────────┐
│   ...방 scene...                      │
│   😊  😴  🎉  😤                      │
│  ┌──────────┐                        │
│  │ 👥 4 / 5 │ ← 좌하단 작은 캡슐      │
│  └──────────┘                        │
└──────────────────────────────────────┘
```

- 위치: scene 좌하단 `(8dp, 8dp)` inset
- 크기: 가로 `auto`, 세로 28dp, 좌우 패딩 10dp
- 배경: `surface.withOpacity(0.9)` + 1px `outline.withOpacity(0.2)`
- 모서리: `BorderRadius.circular(14)` (캡슐형)
- 그림자: `BoxShadow(blur: 4, y: 1, color: 0x14000000)`
- 라벨: `👥 {verifiedCount} / {totalCount}` — 11dp medium, `onSurface`
- 탭 → `showModalBottomSheet` 로 `MembersBottomSheet` 오픈
- 미인증 멤버가 있을 때 라벨 좌측에 작은 빨간 점(`Color(0xFFEF5350)` 6×6 dot)으로 "콕 찌를 사람 있음" 힌트

### MembersBottomSheet 구조

```
┌─────────────────────────────────────┐
│           ───── (handle)            │
│                                     │
│ 챌린지원                  4 / 5 인증 │
├─────────────────────────────────────┤
│                                     │
│ 😊 철수 (나)              ✅ 인증완료 │
│ 😴 영희                   👈 콕!     │  ← 미인증, 콕찌르기 버튼
│ 🎉 민수                   ✅ 인증완료 │
│ 😤 지은                   콕 완료    │  ← 이미 콕 보냄
│ 😊 수진 👑                ✅ 인증완료 │  ← 방장
│                                     │
│              [닫기]                 │
└─────────────────────────────────────┘
```

- `showModalBottomSheet(isScrollControlled: true, useSafeArea: true)`
- 최대 높이: 화면 높이의 70%
- 멤버 행 사양: 기존 `_MemberRow` (member_nudge_list.dart) **그대로 재사용** — UI/액션 변경 없음
- 정렬: 미인증 → 인증완료 (기존 정렬 유지)
- 헤더: "챌린지원" + 우측 인증 통계 `{verified} / {total} 인증`
- 시트 dismiss: 핸들 드래그 다운 / 외부 탭 / "닫기" 버튼
- 콕찌르기 후 시트 자동 닫힘 없음 — 연속 콕찌르기 가능

### 진입점 정리

`MembersBottomSheet` 진입 경로 두 곳:

1. 캐릭터 방 좌하단 **"전체 멤버 보기"** 캡슐 버튼 (주 진입점)
2. (옵션) NudgeBanner 의 "콕 받음" 알림 탭 시에도 시트 오픈 — 콕 보낸 사람을 강조해서 표시

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
| 오늘 셀이 첫 째주 첫 칸 | 좌상단 마커가 month-row label 과 겹치지 않게 z-order 최상위 + cell padding 2dp 보장 |
| `MembersBottomSheet` 멤버 수 매우 많음 (8+) | 시트 내부 `ListView`(스크롤) — 최대 높이 70vh 안에서 |
| "전체 멤버 보기" 버튼 — 멤버 1명(나만) | 버튼 숨김. 시트 진입 동선 자체를 제거. |
| 챌린지 시작 전 / 완료 후 캘린더 셀 탭 | 기존 dialog 유지 — 인증 진입 분기 미적용 |

## Implementation Priority

이 디자인은 front 워크트리에서 구현:

1. **Phase 1**: ChallengeRoomScene (방 배경 + 정적 캐릭터 배치)
2. **Phase 2**: RoomCharacter (인증 상태별 비주얼 + 터치 상호작용)
3. **Phase 3**: CelebrationOverlay (전원 인증 축하 연출)
4. **Phase 4**: 가구 인터랙션 (게시판, 달력판 터치)
5. **Phase 5 (2026-04-19 개정)**: 하단 레이아웃 정리
   - `_TodaySection` 제거 + `_onDayTap` 분기 추가 (오늘+미인증 → `/verify` 직접 진입)
   - `calendar_day_cell.dart` 오늘 셀 강조 (테두리 + 마커)
   - `MembersBottomSheet` 신규 + `_MemberSection` inline 제거
   - scene 좌하단 `_AllMembersTriggerButton` 캡슐 추가

## Related

- `docs/design/miniroom-cyworld.md` — 개인 미니룸 디자인 (공유 색상/패턴)
- `docs/design/challenge-room-speech.md` — 카톡식 한 줄 입력 바 (scene 직하부 위치)
- `docs/design/room-decoration.md` — 방 꾸미기 슬롯 시스템 (signature 와 z-order 고려)
- `app/lib/features/challenge_space/screens/challenge_space_screen.dart` — 현재 챌린지 방
- `app/lib/features/challenge_space/widgets/calendar_day_cell.dart` — 오늘 셀 강조 적용 대상
- `app/lib/features/challenge_space/widgets/member_nudge_list.dart` — `_MemberRow` 시트에서 재사용
- `app/lib/core/widgets/character_avatar.dart` — 픽셀아트 캐릭터 렌더러
- `app/lib/core/widgets/tappable_character.dart` — 탭 반응 위젯
