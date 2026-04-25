---
date: 2026-04-25
worktree: feature
role: feature
slug: remove-challenge-member-list
---

# 챌린지 방 하단 챌린지원 리스트 제거

## Request

> 챌린지 방에서 아래 챌린지원 리스트 없애줘. 어차피 방에서 다 볼수 있으니까.

## Root cause / Context

`ChallengeSpaceScreen` 본문 하단에 `MemberNudgeList` 기반 `_MemberSection` 이 멤버 행 리스트를 표시하고 있었다. 동일한 멤버는 이미 상단 `ChallengeRoomScene` 에 캐릭터로 렌더되며, 콕 찌르기도 캐릭터 탭으로 동일하게 트리거된다 (`app/lib/core/widgets/challenge_room_scene.dart:344` `onTap: ... => _onNudge(member)`). 결과적으로 하단 리스트는 정보·기능 모두 중복이라 사용자가 제거 요청.

본 작업은 최근의 챌린지 방 슬림화 시리즈(`74a3c5e refactor: 한마디(RoomSpeech) 제거`, `206274b refactor: 댓글(Comment) 제거`) 와 같은 흐름이다.

## Actions

| 변경 | 파일 |
|------|------|
| `_MemberSection` 위젯 호출 + sized box 제거 (Today 섹션 다음의 `if (calendarData != null) _MemberSection(...)`) | `app/lib/features/challenge_space/screens/challenge_space_screen.dart` |
| `_MemberSection` 클래스 정의 제거 | 동일 |
| `import '../widgets/member_nudge_list.dart'` 제거 | 동일 |
| 위젯 파일 삭제 (다른 참조 없음) | `app/lib/features/challenge_space/widgets/member_nudge_list.dart` |

콕 찌르기 / 캐릭터 시트 / 멤버 인증 상태 표시는 `ChallengeRoomScene` + `RoomCharacter` 경로에 전부 남아 있다. `MemberNudgeList` 제거로 손실되는 기능 없음.

## Verification

```
$ rg -l "member_nudge_list|MemberNudgeList" app
(no output)
```
→ 잔존 참조 0건.

```
$ flutter analyze lib/features/challenge_space/
44 issues found. (ran in 1.7s)
```
→ 모두 사전부터 존재하던 freezed `JsonKey.new` 경고 / `withOpacity` deprecation / `prefer_const_constructors` info. 본 변경이 신규 에러 도입 없음. (`package:dio/dio.dart` unused import 도 HEAD 부터 존재하던 사전 경고 — 본 작업 범위 밖.)

```
$ flutter build ios --simulator
Xcode build done.                                           24.5s
✓ Built build/ios/iphonesimulator/Runner.app
```

```
$ xcrun simctl install ... && xcrun simctl launch ...
com.example.haeda: 82278
```

런치 캡처: `docs/reports/screenshots/2026-04-25-feature-remove-member-list-01.png` — 홈(내 페이지) 정상 표시, 디버그 배너 OK.

**검증 미완 부분**: `idb` 등 자동 탭 도구 미설치 (`feedback_ios_auto_tap_tooling.md`) 로 챌린지 상세 진입 후 하단 리스트 부재를 시뮬레이터 내에서 자동 캡처하지 못함. 사용자 시뮬레이터 수동 검증 필요.

## Follow-ups

- 사용자 수동 확인: 챌린지(`운동 30일`) 진입 → "오늘" 섹션 하단에 챌린지원 리스트가 보이지 않는지 확인.
- 후속 슬림화 후보가 더 있는지 사용자 결정 대기 (RoomSpeech, Comment, MemberList 가 차례로 제거됨).

## Related

- 코드: `app/lib/features/challenge_space/screens/challenge_space_screen.dart` (수정), `app/lib/features/challenge_space/widgets/member_nudge_list.dart` (삭제)
- 인접 커밋: `74a3c5e`, `206274b` (같은 시리즈 — 한마디·댓글 제거)
- 콕 찌르기 잔존 경로: `app/lib/core/widgets/challenge_room_scene.dart:105,344`, `app/lib/features/challenge_space/widgets/nudge_bottom_sheet.dart`
