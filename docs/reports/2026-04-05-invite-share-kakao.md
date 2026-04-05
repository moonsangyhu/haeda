# Feature Report: 초대 코드 공유를 복사+카카오톡 전용으로 변경

- Date: 2026-04-05
- Area: frontend
- Status: complete

## Requirement
초대 코드 공유 기능을 수정: share_plus(시스템 공유 시트/메일 포함)를 제거하고, 복사 + 카카오톡 공유만 남긴다.

## Changed Files
- `app/pubspec.yaml` — share_plus 제거, kakao_flutter_sdk_share 추가
- `app/pubspec.lock` — 의존성 갱신
- `app/lib/core/config/kakao_config.dart` — KakaoConfig 클래스 신규 생성 (appKey, nativeAppKey, redirectUri)
- `app/lib/core/widgets/invite_share_buttons.dart` — InviteShareButtons 위젯 신규 생성 (복사 + 카카오톡 FeedTemplate 공유)
- `app/lib/main.dart` — KakaoSdk.init() 초기화 추가
- `app/lib/features/auth/screens/kakao_oauth_screen.dart` — KakaoConfig import 경로 반영
- `app/lib/features/auth/screens/login_screen.dart` — KakaoConfig import 추가 (누락 수정)
- `app/lib/features/challenge_create/screens/challenge_create_complete_screen.dart` — 인라인 복사/공유 버튼을 InviteShareButtons로 교체
- `app/lib/features/challenge_space/screens/challenge_space_screen.dart` — Share.share()를 바텀시트 InviteShareButtons로 교체
- `app/test/features/challenge_create/screens/challenge_create_complete_screen_test.dart` — 테스트 키/이름 업데이트, 카카오톡 버튼 테스트 추가
- `app/test/core/widgets/invite_share_buttons_test.dart` — InviteShareButtons 위젯 테스트 신규 생성
- `app/web/index.html` — Kakao JS SDK 스크립트 추가 (웹 공유 지원)
- `.claude/settings.json` — 존재하지 않는 hook 스크립트 참조 제거

## Frontend Changes
- `share_plus` 패키지 제거 → 시스템 공유 시트(메일, SMS 등) 경로 완전 제거
- `kakao_flutter_sdk_share` 패키지 추가 및 KakaoSdk 초기화
- `InviteShareButtons` 공용 위젯: 코드 복사 + 카카오톡 FeedTemplate 공유
- 카카오톡 미설치 시 클립보드 복사 fallback
- 챌린지 생성 완료 화면: InviteShareButtons 직접 렌더링
- 챌린지 스페이스 화면: 💌 아이콘 탭 → 바텀시트로 InviteShareButtons 표시
- `web/index.html`에 Kakao JS SDK v2.7.4 추가 → 웹에서도 카카오톡 공유 정상 동작

## Backend Changes
N/A

## QA Results
- Backend tests: N/A
- Frontend tests: 92 passed, 0 failed
- Lint: 111 warnings (기존 JsonKey/prefer_const — 이번 변경 무관)
- QA verdict: complete
- Smoke test: 사용자 확인 완료 (웹에서 카카오톡 공유 정상 동작)

### Acceptance Criteria
| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | share_plus 패키지 제거, kakao_flutter_sdk_share로 대체 | PASS | pubspec.yaml diff 확인 |
| 2 | 초대 코드 복사 버튼 동작 | PASS | copy_code_button 테스트 통과 |
| 3 | 카카오톡 공유 버튼 존재 및 FeedTemplate 사용 | PASS | kakao_share_button 테스트 통과, 코드 확인 |
| 4 | 카카오톡 미설치 시 클립보드 복사 fallback | PASS | 코드 리뷰 확인 (isKakaoTalkSharingAvailable 분기) |
| 5 | 챌린지 생성 완료 화면에서 InviteShareButtons 사용 | PASS | challenge_create_complete_screen_test 통과 |
| 6 | 챌린지 스페이스 화면에서 바텀시트로 InviteShareButtons 사용 | PASS | 코드 diff 확인 |
| 7 | 메일/시스템 공유 시트 코드 잔재 없음 | PASS | grep share_plus 결과 0건 |
| 8 | 기존 테스트 통과 | PASS | 92 passed, 0 failed |

## Remaining Risks
- None identified

## Push
- Eligible: yes
- Reason: QA complete, 전체 테스트 통과, share_plus 잔재 없음
