# Feature Report: Explore tab auto-refresh on entry

- Date: 2026-04-05
- Area: frontend
- Status: complete

## Requirement
챌린지 공개 생성하고 돌아와서 탐색 탭 누르면 한번에 안 뜸. 탭 진입 시 최신 데이터로 자동 갱신 필요.

## Changed Files
- `app/lib/features/explore/screens/explore_screen.dart` — ConsumerWidget → ConsumerStatefulWidget, initState에서 provider invalidate

## Frontend Changes
ExploreScreen을 ConsumerStatefulWidget으로 변경. initState()에서 Future.microtask로 publicChallengesProvider를 invalidate하여 탭 진입 시마다 최신 공개 챌린지 목록을 fetch.

## Backend Changes
N/A

## QA Results
- Backend tests: N/A (변경 없음)
- Frontend tests: 92 passed, 0 failed
- Lint: pass (0 errors)
- QA verdict: complete

### Acceptance Criteria
| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | 탐색 탭 진입 시 최신 데이터 갱신 | PASS | initState에서 invalidate 호출 |
| 2 | 카테고리 필터 정상 동작 | PASS | 기존 로직 유지 |
| 3 | pull-to-refresh 정상 동작 | PASS | 기존 로직 유지 |
| 4 | flutter analyze error 0 | PASS | 110 info only |
| 5 | flutter test 전체 통과 | PASS | 92/92 |

## Remaining Risks
- None identified

## Push
- Eligible: yes
- Reason: QA complete, all tests pass, report exists, frontend only
