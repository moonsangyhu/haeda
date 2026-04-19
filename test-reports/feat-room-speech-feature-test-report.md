# feat-room-speech-feature Test Report

> Last updated: 2026-04-19
> Verdict: **Complete**

## Slice Overview

| 항목 | 내용 |
|------|------|
| Feature | Challenge Room Speech Bubble (P2) |
| Goal | 챌린지 방 캐릭터 위에 하얀 말풍선 round-robin 표시 + 입력 UX |
| Spec | `docs/design/challenge-room-speech.md` |
| Related impl-log | `impl-log/feat-room-speech-feature.md` |

## Backend Tests

Command: `cd server && uv run pytest tests/test_room_speech.py -v`

| # | 테스트 | 결과 | 목적 |
|---|--------|------|------|
| 1 | `test_post_normal` | PASS | 정상 발언 POST → 200, content/expires_at 반환 |
| 2 | `test_post_empty_content` | PASS | 빈 content POST → 422 `SPEECH_EMPTY` |
| 3 | `test_post_too_long` | PASS | 41자 content POST → 422 `SPEECH_TOO_LONG` |
| 4 | `test_post_newline_stripped` | PASS | 줄바꿈 포함 content → 서버가 제거 후 저장 |
| 5 | `test_post_non_member` | PASS | 비멤버 POST → 403 `SPEECH_NOT_MEMBER` |
| 6 | `test_post_rate_limited` | PASS | 10초 내 재전송 → 429 `SPEECH_RATE_LIMITED` |
| 7 | `test_post_upsert` | PASS | 동일 유저 재전송 → 행 1개 유지, content 갱신 |
| 8 | `test_get_returns_list` | PASS | GET → `{"data": [...]}` 응답 형식 및 내용 확인 |
| 9 | `test_get_excludes_expired` | PASS | expires_at 과거 행은 GET 응답에서 제외 |
| 10 | `test_get_non_member` | PASS | 비멤버 GET → 403 `SPEECH_NOT_MEMBER` |
| 11 | `test_delete_removes_row` | PASS | DELETE → 행 제거, 이후 GET에서 미노출 |
| 12 | `test_delete_idempotent` | PASS | 이미 삭제된 상태에서 DELETE → 200 ok (에러 없음) |

**Summary**: 12 passed, 0 failed

Full suite regression:

Command: `cd server && uv run pytest -v`

**Summary**: 107 passed, 0 failed (1.77s)

## Frontend Tests

Command: `cd app && flutter test test/features/challenge_space/widgets/speech_bubble_test.dart`

| # | 테스트 | 결과 | 목적 |
|---|--------|------|------|
| 1 | `renders speech bubble with text` | PASS | `SpeechBubble` 위젯이 전달된 텍스트 렌더 확인 |
| 2 | `long press opens SpeechInputSheet` | PASS | 600ms 롱-프레스 → 바텀시트 오픈 |
| 3 | `bubble cycles 3 times per turn` | PASS | `RoomSpeechController` round-robin 3회 반복 로직 |
| 4 | `opacity animates fade in and out` | PASS | `bubbleOpacity` 0→1→0 애니메이션 시퀀스 검증 |
| 5 | `accessibility semantics label set` | PASS | `Semantics(label: '$nickname: $content', liveRegion: true)` 설정 확인 |

**Summary**: 5 passed, 0 failed

Full challenge_space suite:

Command: `cd app && flutter test test/features/challenge_space/`

**Summary**: 36 passed, 0 failed

## Lint

Command: `cd app && flutter analyze`

결과: `0 errors, 0 warnings` (수정 대상 파일 기준)

## Build

Command: `cd app && flutter build ios --simulator`

결과: `Built build/ios/iphonesimulator/Runner.app` — 성공

## Deploy

| 항목 | 결과 |
|------|------|
| docker compose backend rebuild | OK |
| `GET /health` | 200 OK |
| Alembic revision | `016` 적용 완료 |
| `room_speeches` 테이블 | postgres 확인 완료 |
| Smoke endpoint `GET /api/v1/challenges/.../room-speech` | 401 (인증 필요 — 라우트 등록 확인) |
| iOS 시뮬레이터 앱 기동 | 정상 (로그인 화면 진입) |

## Simulator Screenshots

| 스크린샷 | 경로 | 비고 |
|---------|------|------|
| 앱 기동 (로그인 화면) | `docs/reports/screenshots/2026-04-19-feature-room-speech-01.png` | 앱 정상 부팅 확인 |

## Manual Verification (미완료)

아래 항목은 실제 로그인 + 활성 챌린지 환경에서 수동으로 확인이 필요하다. 다음 세션에서 진행 예정.

- 챌린지 방 진입 후 말풍선 round-robin 순환 확인 (2명 이상 발언 시)
- 내 캐릭터 롱-프레스 → `SpeechInputSheet` 오픈 → "말하기" 제출 → 토스트 "방에 한마디 전했어요 🗣️"
- "지우기" 버튼으로 발언 삭제 후 큐에서 제거 확인
- 60초 polling 갱신 확인

## Acceptance Criteria

| # | 기준 | 결과 | 근거 |
|---|------|------|------|
| 1 | GET/POST/DELETE 엔드포인트 구현 | PASS | 12/12 테스트 통과 |
| 2 | `room_speeches` 테이블 migration `016` | PASS | alembic upgrade head 완료, 테이블 존재 확인 |
| 3 | `SpeechBubble` 위젯 + fade 애니메이션 (3회 반복) | PASS | speech_bubble_test.dart 5/5 |
| 4 | `RoomSpeechController` round-robin 단일 타이머 | PASS | provider 테스트 + 빌드 확인 |
| 5 | `SpeechInputSheet` 롱-프레스(600ms) 진입 | PASS | long press 테스트 PASS + 빌드 확인 |
| 6 | `flutter analyze` 0 errors | PASS | 수정 파일 기준 0 errors |
| 7 | pytest 12/12 | PASS | 12 passed |
| 8 | 실제 UX 시뮬레이터 수동 검증 | [unverified] | 로그인 후 수동 확인 필요 |

## Verdict

- **Feature complete**: Complete (코드·테스트·빌드 기준)
- **Proceed**: Yes (수동 UX 검증은 다음 세션 진행 가능)
- **Reason**: 모든 자동화 테스트 통과, 빌드 성공, deployer 헬스체크 통과. 실제 UX 수동 검증만 미완료.
