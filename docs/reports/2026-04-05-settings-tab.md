# Feature Report: Settings tab with profile and logout

- Date: 2026-04-05
- Area: frontend
- Status: complete

## Requirement
설정 탭을 하단 네비게이션 맨 오른쪽에 추가. 로그인 정보 확인, 로그아웃, 로컬 앱 설정 포함.

## Changed Files
- `app/lib/features/settings/screens/settings_screen.dart` — 신규: 설정 화면 (프로필, 다크모드, 알림, 로그아웃)
- `app/lib/features/settings/providers/settings_provider.dart` — 신규: SharedPreferences 기반 로컬 설정
- `app/lib/core/widgets/main_shell.dart` — 4번째 설정 탭 추가
- `app/lib/app.dart` — /settings 라우트 + StatefulShellBranch 추가
- `app/lib/main.dart` — SharedPreferences 초기화
- `app/pubspec.yaml` — shared_preferences 패키지 추가

## Frontend Changes
하단 네비게이션에 4번째 "설정" 탭 추가. 설정 화면에 프로필 정보(닉네임, 프로필 이미지), 다크모드/알림 토글(SharedPreferences 로컬 저장), 로그아웃 버튼 구현.

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
| 1 | 하단 네비 4번째 설정 탭 | PASS | main_shell.dart에 Icons.settings 추가 |
| 2 | 프로필 정보 표시 | PASS | settings_screen.dart 프로필 섹션 |
| 3 | 로그아웃 동작 | PASS | auth_provider.logout() → /login 이동 |
| 4 | 로컬 설정 저장 | PASS | SharedPreferences 기반 settings_provider |
| 5 | flutter analyze error 0 | PASS | 110 info only |
| 6 | flutter test 전체 통과 | PASS | 92/92 |

## Remaining Risks
- None identified

## Push
- Eligible: yes
- Reason: QA complete, all tests pass, report exists, frontend only
