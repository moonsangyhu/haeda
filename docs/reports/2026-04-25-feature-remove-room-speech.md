# 챌린지 방 한마디 (RoomSpeech) 기능 전체 제거

- **Date**: 2026-04-25
- **Worktree (수행)**: `.claude/worktrees/feature` (worktree-feature)
- **Worktree (영향)**: feature 단일
- **Role**: feature

## Request

> "에뮬레이터 보니까 챌린지 방에 '방에 한마디 보내기' 대화창이 아직 남아있어."

당일 직전 PR (#58) 에서 댓글(Comment) 기능을 제거했지만, 챌린지 방 안의 또 다른 "말하는" 기능인 RoomSpeech (말풍선·"방에 한마디 보내기" 입력 바) 가 남아 있음을 사용자가 시뮬레이터에서 발견. 동일하게 풀 제거.

## Root cause / Context

- "챌린지 방에서 말하는 기능" 이라는 사용자 의도에는 두 갈래가 존재했음:
  1. **댓글 (Comment)** — 인증 상세 화면의 댓글 목록·입력. PR #58 에서 제거 완료.
  2. **챌린지 방 한마디 (RoomSpeech)** — 챌린지 방 캐릭터 위 말풍선 + 카톡식 인라인 입력 바 ("방에 한마디 보내기"). 본 PR 에서 제거.
- 댓글과 같은 "복잡하기만 하고 인증 자체에 집중을 분산시키는 기능" 카테고리. MVP scope 단순화 결정 (`docs/prd.md` §4).
- 챌린지 방의 캐릭터 표시 / 콕 찌르기 / 인증 / 달력 / 전원 인증 보상 등 핵심 기능은 모두 그대로 유지. 말풍선/입력 바만 제거.

## Actions

### 1. Backend code removal
- `server/app/models/room_speech.py`, `schemas/room_speech.py`, `services/room_speech_service.py`, `routers/room_speech.py` 모두 삭제.
- `server/app/main.py`: `room_speech` import 및 `app.include_router(room_speech.router, ...)` 제거.
- `server/app/models/__init__.py`: `RoomSpeech` import 및 export 제거.
- `server/tests/test_room_speech.py` 삭제 (12 테스트).

### 2. Backend migration
- `server/alembic/versions/20260425_0001_019_drop_room_speeches.py` 신규 작성:
  - `upgrade`: `ix_room_speeches_challenge_expires` 인덱스 + `uq_room_speeches_member` UNIQUE 제약 + `room_speeches` 테이블 drop.
  - `downgrade`: 016 migration 과 동일한 스키마(challenge_id FK, user_id FK, content varchar(40), created_at, expires_at) 로 재생성, UNIQUE / INDEX 복구.

### 3. Frontend code removal
- `app/lib/features/challenge_space/widgets/speech_bubble.dart` 삭제.
- `app/lib/features/challenge_space/widgets/speech_input_bar.dart` 삭제.
- `app/lib/features/challenge_space/providers/room_speech_provider.dart` 삭제.
- `app/lib/features/challenge_space/api/room_speech_api.dart` 삭제.
- `app/lib/features/challenge_space/models/room_speech.dart` (+ `*.freezed.dart`, `*.g.dart`) 삭제.
- `app/test/features/challenge_space/widgets/speech_bubble_test.dart` 삭제 (5 테스트).

### 4. Frontend wiring 정리
- `app/lib/core/widgets/challenge_room_scene.dart`:
  - `room_speech_provider` import / `RoomSpeechController` 의존 제거.
  - `WidgetsBindingObserver` mixin / `_speechParams` 필드 / `_initSpeech()` / `didChangeAppLifecycleState()` / `didUpdateWidget()` 의 speech block 제거.
  - `_buildCharacterWidget()` 시그니처에서 `speechController` 인자 제거, `RoomCharacter` 호출에서 `speechText` / `bubbleOpacity` / `bubbleScale` 인자 제거.
- `app/lib/features/challenge_space/widgets/room_character.dart`:
  - `speech_bubble.dart` import 제거.
  - `RoomCharacter` 의 `speechText` / `bubbleOpacity` / `bubbleScale` 파라미터 제거.
  - `_hasSpeech` getter 및 SpeechBubble 위젯 렌더 제거.
  - 탭 시 표시되는 wave bubble 의 `_hasSpeech` 의존 조건 단순화.
- `app/lib/features/challenge_space/screens/challenge_space_screen.dart`:
  - `speech_input_bar.dart` import 제거.
  - `SpeechInputBar(challengeId: ..., currentUserId: ..., myNickname: ...)` 위젯 사용 제거 (남은 `SizedBox(height: 8)` 만 유지).

### 5. Docs source-of-truth 동기화
- `docs/prd.md`:
  - F-30 (챌린지 방 한마디 / Room Speech) 항목 삭제.
  - §4 MVP 제외 범위 행을 "채팅 / 댓글 / 실시간 메시지 / 챌린지 방 한마디" 로 확장하고 "2026-04-25 사용자 결정으로 댓글·Room Speech 기능 모두 제거" 로 갱신.
- `docs/api-contract.md`:
  - §10 Room Speech (P2) 섹션 통째로 삭제 (3 엔드포인트 GET/POST/DELETE + 4 에러 코드 SPEECH_NOT_MEMBER / SPEECH_EMPTY / SPEECH_TOO_LONG / SPEECH_RATE_LIMITED).
  - 후속 §11 Room Decoration → §10 으로 번호 재조정.
- `docs/domain-model.md`:
  - §2.12 RoomSpeech (P2) 엔티티 정의 + 비즈니스 룰 삭제.
  - §2.13 RoomEquipMr → §2.12, §2.14 → §2.13, §2.15 → §2.14 로 번호 재조정.
- `docs/design/specs/challenge-room-speech.md`:
  - frontmatter `status: ready` → `status: dropped`, `dropped: 2026-04-25` 필드 추가.
  - 본문 상단에 DROPPED 배너 (이유 + 본 보고서 경로) 추가.
  - 스펙 본문 자체는 삭제하지 않고 추후 재도입 시 참조용으로 보존.

### 6. seed 정리
- `server/seed.py` 의 truncate 목록에 `room_speeches` 가 원래 포함되어 있지 않아 별도 수정 불필요. migration 019 가 테이블을 drop 하므로 다음 seed 실행 시 ProgrammingError 도 발생하지 않음.

## Verification

### Backend
- `docker compose up --build -d backend` — 이미지 재빌드 + 컨테이너 재기동 성공.
- alembic 로그: `INFO  [alembic.runtime.migration] Running upgrade 018 -> 019, drop room_speeches table` 적용 확인.
- `curl -fsS http://localhost:8000/health` → `{"status":"ok"}` (HTTP 200).
- `pytest tests/ --tb=short -q` (container venv, dev deps 설치 후):
  ```
  ............................ (생략)
  2 failed, 108 passed in 3.03s
  ```
  실패한 2개는 `test_room_equip.py::TestSignature::test_member_clear_signature` 및 `test_non_member_clear_signature_returns_403` (Room Decoration P2 의 422 vs 200/403 응답 불일치). 이 두 실패는 어제 PR #58 시점에도 동일하게 발생한 **사전 존재 실패**로, 본 작업과 무관.
- 본 작업 직전(직전 PR 머지 직후) 122 → 본 작업 후 110 테스트 (test_room_speech.py 12개 삭제 = 122 - 12 = 110 일치). pytest 가 collect 한 110 - 2 = 108 passed.

### Frontend
- `flutter pub get` + `dart run build_runner build --delete-conflicting-outputs` → `Succeeded after 15.1s with 164 outputs`.
- `flutter analyze --no-pub` → 201 issues, **모두 info-level** (`prefer_const_constructors`), error 없음.
- `flutter test --no-pub test/features/challenge_space/` → `00:01 +30: All tests passed!` (이전 35 → 30, speech_bubble_test 5개 제거).
- `flutter build ios --simulator` → `✓ Built build/ios/iphonesimulator/Runner.app` (27.3s).
- iOS simulator clean install (terminate → uninstall → flutter clean → pub get → build → install → launch):
  - Device: iPhone 17 Pro `463EC4CF-2080-47FE-8F26-530FFB713C06`, Bundle: `com.example.haeda`.
  - `xcrun simctl install` + `xcrun simctl launch` 성공, PID 76552 으로 앱 실행 중.

### 잔여 검증 (사용자 수동 확인 필요)
- 챌린지 방 진입 시 캐릭터 위 말풍선이 사라졌는지 시각 확인.
- 챌린지 방 하단의 "방에 한마디 보내기" 입력 바가 완전히 사라졌는지 시각 확인.
- 챌린지 방의 캐릭터 표시 / 콕 찌르기 / 인증 흐름 / 전원 인증 폭죽 효과 등은 그대로 동작하는지 시각 확인.

## Follow-ups

- 사전 존재 실패 2종(Room Decoration signature 422 응답 + frontend status_bar / feed_screen / profile_setup_screen / time_test) 은 본 작업 범위 밖. 별도 fix 세션 필요.
- `docs/design/specs/challenge-room-speech.md` 는 status=dropped 로 표시만 하고 본문은 보존. 추후 채팅/한마디 류 도입 의도가 다시 들어오면 본 결정 (`docs/prd.md` §4 MVP 제외 범위 + 본 보고서) 을 명시적으로 뒤집어야 함.
- `docs/architecture.md`, `docs/raw-requirements.md`, `docs/decisions/` 등은 본 작업에서 손대지 않음. 한마디 관련 언급이 남아있다면 후속 정리 필요 (`grep -rn "한마디\|RoomSpeech\|Room Speech" docs/` 로 점검).

## Related

- 직전 PR: #58 (`refactor: 챌린지 방 댓글(Comment) 기능 전체 제거`, commit `206274b`). 동일 사용자 의도 ("챌린지 방에서 말하는 기능 제거") 의 1차 갈래였음.
- 사전 보고서: `docs/reports/2026-04-25-feature-remove-comment-feature.md` (댓글 제거).

### Referenced Reports

- `docs/reports/2026-04-25-feature-remove-comment-feature.md` — 동일 사용자 의도의 1차 작업 (Comment 제거). 본 작업은 그 후속으로, 같은 풀-제거 패턴(코드 + alembic drop migration + docs source-of-truth 동기화 + design spec status=dropped) 을 동일하게 적용.

— 검색 키워드: `RoomSpeech`, `room_speech`, `Room Speech`, `한마디`, `speech_bubble`, `SpeechInputBar`, `방에 한마디`. `docs/reports/` 에서 위 1건만 매칭.
