# feat(app): show completion screen from calendar, not directly from challenge tap

- **Date**: 2026-04-10
- **Commit**: eb47cf9
- **Area**: frontend

## What Changed

완료된 챌린지를 my page에서 탭하면 완료 화면으로 직행하던 것을 달력(챌린지 공간)으로 변경. 달력에서 allCompleted 날짜(계절 아이콘)를 탭하면 완료 화면으로 이동. 완료된 챌린지의 달력 상단에 "챌린지 완료 결과 보기" 배너 추가.

## Changed Files

| File | Change |
|------|--------|
| app/lib/features/my_page/screens/my_page_screen.dart | 완료 챌린지 라우팅을 `/challenges/{id}/completion` → `/challenges/{id}`로 변경 |
| app/lib/features/challenge_space/screens/challenge_space_screen.dart | `_onDayTap`에 allCompleted 체크 추가, `_CompletionBanner` 위젯 추가, status 필드 전달 |

## Implementation Details

- `_onDayTap` 시그니처에 `List<DayEntry> days` 파라미터 추가하여 해당 날짜의 allCompleted 여부 확인
- allCompleted 날짜 탭 시 `/challenges/$challengeId/completion`으로 `context.push` (뒤로가기로 달력 복귀 가능)
- `_ChallengeSpaceBody`에 `status` 필드 추가, `ChallengeDetail.status`를 부모에서 전달
- status == 'completed'일 때 `_CompletionBanner` 위젯 표시 (NudgeBanner 아래, MonthNavigator 위)

## Tests & Build

- Analyze: pass (2 info-level only)
- Tests: skipped
- Build: flutter build web pass + iOS simulator 실행 확인
