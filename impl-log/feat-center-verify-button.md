# feat: change center nav button from create to verify, add FAB for create

- **Date**: 2026-04-10
- **Commit**: 853bbb3
- **Area**: both (frontend + backend)

## What Changed

하단 내비게이션 중앙 버튼을 "만들기"(챌린지 생성)에서 "인증"(오늘의 인증)으로 변경. 챌린지 생성은 내 챌린지 탭의 FAB로 이동. 인증 버튼 탭 시 바텀시트로 활성 챌린지 목록과 인증 상태를 보여줌.

## Changed Files

| File | Change |
|------|--------|
| `app/lib/core/widgets/main_shell.dart` | 중앙 버튼 아이콘/라벨 변경 (camera_alt + "인증"), 탭 핸들러 변경 |
| `app/lib/core/widgets/verify_bottom_sheet.dart` | **신규** — 인증 바텀시트 위젯 (활성 챌린지 목록 + 인증 상태) |
| `app/lib/features/my_page/models/challenge_summary.dart` | `todayVerified` 필드 추가 |
| `app/lib/features/my_page/screens/my_page_screen.dart` | FAB 추가 (챌린지 생성) |
| `app/lib/features/challenge_space/screens/create_verification_screen.dart` | 인증 성공 후 `myChallengesProvider` invalidate 추가 |
| `server/app/schemas/challenge.py` | `ChallengeListItem`에 `today_verified: bool` 필드 추가 |
| `server/app/services/challenge_service.py` | `get_my_challenges()`에 오늘 인증 여부 쿼리 추가 |
| `docs/api-contract.md` | `/me/challenges` 응답에 `today_verified` 필드 문서화 |
| `app/test/core/widgets/verify_bottom_sheet_test.dart` | **신규** — 바텀시트 위젯 테스트 4건 |

## Implementation Details

- 중앙 버튼 탭 시 스마트 라우팅: 미인증 챌린지 1개면 바로 인증 화면, 그 외 바텀시트 표시
- 바텀시트는 `NudgeBottomSheet` 패턴 참고 (drag handle, SafeArea, theme 활용)
- Backend에서 `today_verified`는 오늘 날짜의 Verification 존재 여부로 판단 (subquery)
- 인증 성공 후 `myChallengesProvider` invalidate로 바텀시트 상태 갱신 보장

## Tests & Build

- Analyze: 0 errors (122 pre-existing info warnings)
- Tests: 96 passed, 0 failed (Flutter)
- Backend: py_compile OK (pytest 환경 없음 — broken venv symlink)
- Build: flutter build web ✓
