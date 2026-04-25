---
date: 2026-04-25
worktree: feature
role: feature
slug: tap-day-to-verify
---

# 챌린지 방 인증하기 버튼 제거 + 캘린더 날짜 tap 으로 인증

## Request

> 챌린지 방에서 맨 아래 인증하기 버튼도 없애줘. 대신 달력 날짜 선택해서 거기서 인증 가능하도록 해줘

## Root cause / Context

직전 슬림화 시리즈(`74a3c5e` 한마디 / `206274b` 댓글 / PR #60 챌린지원 리스트) 의 연장. 챌린지 방 본문이 점점 단순해지면서 하단 `_TodaySection.ElevatedButton('인증하기')` 의 존재 가치가 줄어들었다. 같은 라우트(`/challenges/$id/verify`) 진입을 캘린더 cell tap 으로 통합하면 인터랙션 표면이 1개로 줄어든다.

기존 캘린더 cell tap 은 `_onDayTap` 에서 `/verifications/$date` 로만 이동했으므로, **오늘 + 본인 미인증** 조건일 때만 `/verify` 로 분기하도록 추가. 다른 모든 분기(시작 전 / 미래 / 다른 사용자만 인증한 오늘 / 과거)는 보존.

## Actions

| 변경 | 파일 / 위치 |
|------|-------------|
| `_onDayTap` 분기 추가: `isToday && !myselfVerified` → `/challenges/$id/verify` | `app/lib/features/challenge_space/screens/challenge_space_screen.dart` `_onDayTap` |
| `_TodaySection` 의 `ElevatedButton('인증하기')` 제거 | 동일 파일 `_TodaySection.build` |
| 미인증 시 안내 hint `'달력의 오늘 날짜를 눌러 인증해 주세요'` 추가 (`bodySmall`, `onSurfaceVariant`) | 동일 |
| `verifiedToday` 분기 인증 완료 메시지("오늘 인증 완료!") 는 그대로 유지 | 동일 |

`ChallengeRoomScene.onVerify` 는 이미 dead callback (룸 씬 내부에서 호출하지 않음). 본 작업 범위 외라 그대로 두고 follow-up. `NudgeBanner.onVerify` (콕 받았을 때 banner tap → 인증) 는 살아있는 사용처라 보존.

## Verification

iOS 25.2 / iPhone 17 Pro / iOS 26.4 / Xcode 26 / `idb` 1.1.7 자동 검증.

```
$ flutter build ios --simulator
Xcode build done.                                           27.1s
✓ Built build/ios/iphonesimulator/Runner.app

$ xcrun simctl install ... && xcrun simctl launch ...
com.example.haeda: 98303
```

UI 트리 어설션 (idb ui describe-all):
```
"인증하기" 버튼: 0개 (기대: 0)        ← 제거됨
오늘 헤더 "오늘 (4월 25일)": 1개      ← 유지
안내 hint "달력의 오늘 날짜를 눌러 인증해 주세요": 1개  ← 신규
25일 cell: center=(366, 640)         ← 좌표 추출
```

25일 cell tap → 진입 화면:
```
Heading     y=  79 인증 작성
StaticText  y= 260 사진 선택 (최대 3장)
StaticText  y= 300 오늘의 일기
Button      y= 520 제출하기
```
→ `/challenges/$id/verify` (인증 작성 화면) 진입 자동 확인.

캡처:
- `docs/reports/screenshots/2026-04-25-feature-tap-to-verify-01-room-no-button.png` — 챌린지 방 하단 (버튼 부재 + hint 노출)
- `docs/reports/screenshots/2026-04-25-feature-tap-to-verify-02-verify-screen.png` — 25일 tap 후 인증 작성 화면

`flutter analyze` 결과 본 변경 도입 신규 이슈 없음 (`unused_import: package:dio/dio.dart` 는 HEAD 부터 있던 사전 경고).

## Follow-ups

- `ChallengeRoomScene.onVerify` 인자는 dead — 다음 정리 작업 시 함께 제거 가능 (`onCalendarTap` 만 살아있음).
- 본인이 이미 인증한 날 cell tap 은 그대로 `/verifications/$date` 로 — 다른 사람들 인증 결과 보기. 동작 변경 없음.
- 시즌·시작 전·미래 알림 다이얼로그 보존.

## Related

- 직전 시리즈: PR #57 한마디 제거 / PR (`206274b`) 댓글 제거 / PR #60 멤버 리스트 제거
- 코드: `app/lib/features/challenge_space/screens/challenge_space_screen.dart` (`_onDayTap`, `_TodaySection`)
- 콕 받았을 때 인증 진입: `app/lib/features/challenge_space/widgets/nudge_banner.dart` (변경 없음)
- 검증 도구: `.claude/skills/haeda-ios-tap/` (PR #61, idb)
