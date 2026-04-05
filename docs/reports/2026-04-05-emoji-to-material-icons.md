# Feature Report: Emoji to Material Icons

- Date: 2026-04-05
- Area: frontend
- Status: complete

## Requirement
앱 전체 이모지 아이콘을 구글 공식 Material Icons로 교체. 시즌 아이콘(🌸🌿🍁❄️)은 유지.

## Changed Files
- `app/lib/core/widgets/main_shell.dart` — 하단 네비게이션 탭 아이콘을 Icon 위젯으로 교체
- `app/lib/features/auth/screens/kakao_oauth_screen.dart` — 뒤로가기 버튼
- `app/lib/features/auth/screens/profile_setup_screen.dart` — 프로필 플레이스홀더, 카메라 아이콘
- `app/lib/features/challenge_complete/screens/challenge_completion_screen.dart` — 뒤로가기, 축하 아이콘
- `app/lib/features/challenge_create/screens/challenge_create_step1_screen.dart` — 뒤로가기
- `app/lib/features/challenge_create/screens/challenge_create_step2_screen.dart` — 뒤로가기, 달력 아이콘
- `app/lib/features/challenge_space/screens/challenge_space_screen.dart` — 뒤로가기, 달력 네비게이션
- `app/lib/features/challenge_space/screens/create_verification_screen.dart` — 뒤로가기, 사진 상태 아이콘
- `app/lib/features/challenge_space/screens/daily_verifications_screen.dart` — 뒤로가기, 편집/체크 아이콘
- `app/lib/features/challenge_space/screens/verification_detail_screen.dart` — 뒤로가기, 이미지 에러
- `app/lib/features/explore/widgets/public_challenge_card.dart` — 달력, 그룹, 카메라 아이콘
- `app/lib/features/challenge_join/screens/invite_preview_screen.dart` — _InfoRow emoji→IconData 리팩토링

## Frontend Changes
28개 이모지를 Material Icons(Icons.*)로 교체. _InfoRow 위젯의 emoji 파라미터를 IconData icon으로 변경. 시즌 아이콘(season_icons.dart, emoji_icon.dart, calendar_day_cell.dart)은 미변경.

## Backend Changes
N/A

## QA Results
- Backend tests: N/A (변경 없음)
- Frontend tests: 92 passed, 0 failed
- Lint: pass (0 errors, 110 info)
- QA verdict: complete

### Acceptance Criteria
| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | 모든 비-시즌 이모지가 Material Icons로 교체 | PASS | 12개 파일 수�� 완료 |
| 2 | 하단 네비게이션 Icon 위젯 사용 | PASS | main_shell.dart Icons.home/explore/notifications |
| 3 | 뒤로가기 버튼 Icons.arrow_back | PASS | 8개 파일 일괄 교체 |
| 4 | 시즌 아이콘 미변경 | PASS | season_icons.dart 변경 없음 |
| 5 | flutter analyze error 0 | PASS | 110 info only |
| 6 | flutter test 전체 통과 | PASS | 92 passed, 0 failed |

## Remaining Risks
- None identified

## Push
- Eligible: yes
- Reason: QA complete, all tests pass, report exists, frontend only changes
