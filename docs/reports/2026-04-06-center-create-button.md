# Feature Report: Center create button in bottom nav (YouTube-style)

- Date: 2026-04-06
- Area: frontend
- Status: complete

## Requirement
챌린지 추가 버튼을 하단 탭 바 가운데에 + 아이콘으로 배치 (유튜브 스타일). 기존 추가 버튼 삭제. Material Icons 사용.

## Changed Files
- `app/lib/core/widgets/main_shell.dart` — 5-destination NavigationBar, 중앙 + 버튼은 /create 네비게이션
- `app/lib/features/my_page/screens/my_page_screen.dart` — 기존 "챌린지 만들기" FilledButton 제거
- `app/test/features/my_page/screens/my_page_screen_test.dart` — 제거된 버튼 테스트 업데이트

## Frontend Changes
하단 네비게이션 바를 5개 탭으로 변경: 내 챌린지 / 탐색 / + (만들기) / 알림 / 설정. 중앙 + 버튼은 실제 탭이 아닌 /create 페이지로 이동하는 액션 버튼. 인덱스 매핑: nav index 0-1은 branch 0-1, nav index 2는 /create 이동, nav index 3-4는 branch 2-3.

## Backend Changes
N/A

## QA Results
- Backend tests: N/A
- Frontend tests: 92 passed, 0 failed
- Lint: pass (0 errors)
- QA verdict: complete

### Acceptance Criteria
| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | 중앙 + 아이콘 탭 | PASS | main_shell.dart Icons.add_circle |
| 2 | + 탭 클릭 시 /create 이동 | PASS | context.push('/create') |
| 3 | 기존 만들기 버튼 제거 | PASS | my_page_screen.dart에서 삭제 |
| 4 | Material Icons 사용 | PASS | Icons.add_circle_outlined/add_circle |
| 5 | 탭 순서 정확 | PASS | 내챌린지/탐색/+/알림/설정 |
| 6 | 테스트 전체 통과 | PASS | 92/92 |

## Remaining Risks
- None identified

## Push
- Eligible: yes
- Reason: QA complete, all tests pass, report exists, frontend only
