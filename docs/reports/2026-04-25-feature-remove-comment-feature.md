# 댓글(Comment) 기능 전체 제거

- **Date**: 2026-04-25
- **Worktree (수행)**: `.claude/worktrees/feature` (worktree-feature)
- **Worktree (영향)**: feature 단일
- **Role**: feature

## Request

> "챌린지 방에서 말하는 기능은 없애줘. 복잡하기만 해서 필요 없다."

사용자 결정: 댓글(Comment) 기능 전체 제거 + DB 테이블 drop migration + docs source-of-truth 동기화 (A안 풀 제거).

## Root cause / Context

- 현재 코드의 "챌린지 방에서 말하는 기능"은 인증 상세 화면(`VerificationDetailScreen`)에 붙어 있던 댓글 입력/목록 UI 가 유일.
- Backend 는 `Comment` 엔티티 + 3개 라우터(`GET /verifications/{id}`, `GET/POST /verifications/{id}/comments`) 로 구성.
- MVP scope 단순화 — 인증 자체에 집중하고 댓글 / 채팅 / 메시지 류는 모두 의도적으로 제외 (`docs/prd.md` §4 MVP 제외 범위 갱신).
- 인증 상세 조회(`GET /verifications/{id}`) 자체는 사진/일기 보기에 필요하므로 **유지** — comments 필드만 제거.

## Actions

### 1. Backend code removal
- `server/app/services/comment_service.py` 삭제.
- `server/app/services/verification_service.py` 에 `get_verification_detail()` 함수 이전 + `Comment` import / `comment_count` 계산 로직 제거.
- `server/app/schemas/comment.py` 삭제.
- `server/app/schemas/verification.py` 에 `VerificationDetailResponse` (comments 필드 없는 형태) 추가, `VerificationItem.comment_count` 필드 제거.
- `server/app/routers/verifications.py`: `GET /verifications/{id}` 만 유지, `/comments` GET·POST 두 엔드포인트 제거.
- `server/app/models/comment.py` 삭제.
- `server/app/models/__init__.py` 에서 `Comment` import / export 제거.
- `server/app/models/user.py` 에서 `comments` relationship 제거.
- `server/app/models/verification.py` 에서 `comments` relationship 제거.
- `server/seed.py` 의 truncate 대상 테이블 목록에서 `"comments"` 제거.

### 2. Backend migration
- `server/alembic/versions/20260425_0000_018_drop_comments.py` 신규 작성:
  - `upgrade`: `idx_comment_verification` 인덱스 + `comments` 테이블 drop.
  - `downgrade`: 동일 스키마(verification_id FK, author_id FK, content varchar(500), created_at) 로 재생성.

### 3. Backend tests
- `server/tests/test_comments.py` 삭제 (8개 테스트).
- `server/tests/test_verification_detail.py` 신규 작성: GET /verifications/{id} 엔드포인트 happy path / NOT_FOUND / NOT_A_MEMBER 3개 테스트만 유지, comments assertion 제거.
- `server/tests/test_verifications.py`: `assert v_item["comment_count"] == 0` → `assert "comment_count" not in v_item` 로 변경.

### 4. Frontend code removal
- `app/lib/features/challenge_space/models/comment_data.dart` (+`*.freezed.dart`, `*.g.dart`) 삭제.
- `app/lib/features/challenge_space/models/verification_data.dart`:
  - `VerificationItem.commentCount` 필드 제거.
  - `VerificationDetail` (comments 필드 없는 형태) 클래스 추가 (이전 `comment_data.dart` 의 동명 클래스 대체).
- `app/lib/features/challenge_space/providers/comment_provider.dart` 삭제.
- `app/lib/features/challenge_space/providers/verification_provider.dart` 에 `verificationDetailProvider` 이전 (FutureProvider.family).
- `app/lib/features/challenge_space/screens/verification_detail_screen.dart`: `_CommentsSection`, `_CommentItemTile`, `_CommentInputBar`, `_onSendComment`, `_commentController`, `commentSubmitProvider` 사용 모두 제거. `ConsumerStatefulWidget` → `ConsumerWidget` 으로 단순화.
- `app/lib/features/challenge_space/screens/daily_verifications_screen.dart`: `💬 ${item.commentCount}` 표시 라인 제거, subtitle 단순화.
- `app/lib/features/character/providers/character_provider.dart`: `comment_provider` import 제거 (verificationDetailProvider 는 verification_provider 로 이동).

### 5. Frontend tests
- `app/test/features/challenge_space/screens/verification_detail_screen_test.dart`: "댓글 섹션" / "댓글 입력창" 두 group 제거, `_CommentData` / `_CommentList` / `_CommentInputBar` helper 위젯 제거.

### 6. Docs source-of-truth 동기화
- `docs/prd.md`:
  - §1.3 핵심 가치 "사진 + 일기 + 댓글" → "사진 + 일기".
  - §1.5 / §2 핵심 루프 / §2.5 / §2.7 / §5 성공 지표에서 댓글 항목 제거.
  - §4 MVP 제외 범위에 "채팅 / 댓글 / 실시간 메시지" 한 줄로 통합 (2026-04-25 결정 명시).
  - F-14 (참여자 간 댓글) 항목 제거, §2.5 섹션명 "인증 & 피드백" → "인증".
- `docs/api-contract.md`:
  - §0 P0 범위 목록에서 Comments 제거.
  - §4 Verifications 응답에서 `comment_count`, `comments` 필드 제거.
  - §5 Comments 섹션(POST/GET 엔드포인트, COMMENT_TOO_LONG 에러) 통째로 삭제, §6→§5 부터 섹션 번호 재조정 (Coins=5, Shop=6, Character=7, Notifications=8, Push=9).
- `docs/domain-model.md`:
  - 핵심 객체 정의에서 댓글 언급 제거.
  - §1 ER 다이어그램에서 Comment 노드 제거.
  - §2.6 Comment 엔티티 정의 삭제, §2.7 부터 번호 재조정 (DeviceToken=2.6, Notification=2.7, GemTransaction=2.8, ...).
  - §3 인덱스 표에서 `idx_comment_verification` 제거.
- `docs/user-flows.md`:
  - P0 범위 목록에서 댓글 제거.
  - Flow 7 제목 "인증 내역 조회 & 댓글" → "인증 내역 조회".
  - Flow 7 본문에서 댓글 목록 / 입력 박스 ASCII 도식 제거.
  - 화면 구조 요약 "인증 상세 (사진+일기+댓글)" → "인증 상세 (사진+일기)".

## Verification

### Backend
- `docker compose up --build -d backend` — Image rebuilt, container Started, alembic upgrade `017 → 018, drop comments table` 적용 확인.
- `curl -fsS http://localhost:8000/health` → `{"status":"ok"}`, HTTP 200.
- `pytest tests/ --tb=short` (container venv, dev deps 설치 후):
  ```
  collected 122 items
  tests/test_appearance.py ........                                        [  6%]
  tests/test_auth.py .............                                         [ 17%]
  tests/test_challenge_create_join.py ............                         [ 27%]
  tests/test_challenges.py ...........                                     [ 36%]
  tests/test_completion.py ....                                            [ 39%]
  tests/test_me.py .....                                                   [ 43%]
  tests/test_room_equip.py .................FF.                            [ 59%]
  tests/test_room_speech.py ............                                   [ 69%]
  tests/test_scheduler.py .........                                        [ 77%]
  tests/test_scheduler_registration.py ..                                  [ 78%]
  tests/test_time.py ...                                                   [ 81%]
  tests/test_unit.py .........                                             [ 88%]
  tests/test_verification_detail.py ...                                    [ 90%]
  tests/test_verifications.py ...........                                  [100%]
  ======================== 2 failed, 120 passed in 23.88s ========================
  ```
- 실패한 2개(`test_room_equip.py::TestSignature::test_member_clear_signature`, `test_non_member_clear_signature_returns_403`) 는 `git stash` 후 동일하게 실패하는 **사전 존재 실패**로, 본 작업과 무관 (Room Decoration P2 신규 기능의 422 vs 200/403 응답 불일치).
- 본 작업 직접 영향: `test_verification_detail.py` 3 PASS, `test_verifications.py` 11 PASS, `test_completion.py` 4 PASS.

### Frontend
- `flutter pub get` + `dart run build_runner build --delete-conflicting-outputs` → `Succeeded after 17.3s with 167 outputs`.
- `flutter analyze --no-pub` → 204 issues, **모두 info-level** (`prefer_const_constructors`), error 없음.
- `flutter test --no-pub test/features/challenge_space/` → `00:04 +35: All tests passed!` (challenge_space 전 테스트 35개).
- 전체 `flutter test --no-pub` 에서 발생한 status_bar / feed_screen / profile_setup_screen / time_test 실패는 `git stash` 후에도 동일하게 실패하는 **사전 존재 실패**, 본 작업과 무관.
- `flutter build ios --simulator` → `✓ Built build/ios/iphonesimulator/Runner.app` (29.6s).
- iOS simulator clean install (terminate → uninstall → flutter clean → pub get → build → install → launch):
  - Device: iPhone 17 Pro `463EC4CF-2080-47FE-8F26-530FFB713C06`, Bundle: `com.example.haeda`.
  - `xcrun simctl install` + `xcrun simctl launch` 성공, PID 66753 으로 앱 실행 중.

### 잔여 검증 (사용자 수동 확인 필요)
- 실제 시뮬레이터 화면에서 인증 상세 화면(`/verifications/{id}`) 진입 시 댓글 섹션·입력 바가 사라졌는지, 날짜별 인증 현황(`/challenges/{id}/verifications/{date}`) 카드에 `💬 N` 표시가 사라졌는지 시각 확인.

## Follow-ups

- 사전 존재 실패 2종(backend 의 Room Decoration signature 422 응답, frontend 의 status_bar / feed_screen / profile_setup_screen / time_test) 은 본 작업 범위 밖. 별도 fix 세션에서 처리 필요.
- 댓글 제거 결정 자체는 `docs/prd.md` §4 MVP 제외 범위에 영구 기록됨. 추후 채팅/댓글 류 도입 요구가 다시 들어오면 이 결정을 명시적으로 뒤집어야 한다.
- `docs/architecture.md`, `docs/raw-requirements.md`, `docs/decisions/` 등은 본 작업에서 손대지 않음. 댓글 언급이 있다면 후속 정리 필요 (`grep -rn "댓글\|Comment" docs/` 로 점검).

## Related

- 이전 보고서: 본 기능과 직접 관련된 사전 보고서 없음 (댓글 기능은 초기 구현부터 한 번도 보고서 단위로 다루어진 적이 없음).
- 변경 파일 목록: 위 §Actions 참조.
- migration: `server/alembic/versions/20260425_0000_018_drop_comments.py`.

### Referenced Reports

관련 선행 작업 없음 — 검색 키워드: `comment`, `Comment`, `댓글`, `verification`, `challenge_space`, `comment_count`. `docs/reports/` 에서 매칭되는 사전 보고서가 발견되지 않음.
