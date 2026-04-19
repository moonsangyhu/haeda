# feat: Challenge Room Speech Bubble (P2)

- **Date**: 2026-04-19
- **Type**: feat
- **Area**: both
- **Worktree**: feature (full-stack waiver — backend + frontend in same worktree)

## Requirement

챌린지 방(ChallengeSpaceScreen)의 미니룸 공간에 모인 캐릭터가 **하얀 말풍선**으로 짧은 한마디를 주고받을 수 있게 한다. 유저당 챌린지당 1건, TTL = 다음 cutoff 시각. 순차 round-robin 표시.

## Plan Source

- 승인 계획: `~/.claude/plans/wondrous-riding-taco.md` (레포 외부, 참조 경로)
- 설계 사양: `docs/design/challenge-room-speech.md`

수락 기준:
- GET/POST/DELETE `/api/v1/challenges/{id}/room-speech` 구현 및 테스트 통과
- `room_speeches` 테이블 migration `016` 적용
- `SpeechBubble` 위젯 + 애니메이션 (fade 180ms + hold 3s, 3회 반복)
- `RoomSpeechController` round-robin 큐 (`Timer.periodic` 단일 타이머)
- `SpeechInputSheet` 롱-프레스(600ms) 진입 바텀시트
- `flutter analyze` 0 errors, pytest 12/12

## Implementation

### Backend

| 파일 | 목적 |
|------|------|
| `server/app/models/room_speech.py` | SQLAlchemy 2.0 async 모델. UNIQUE `(challenge_id, user_id)`, INDEX `(challenge_id, expires_at)` |
| `server/app/schemas/room_speech.py` | Pydantic v2 스키마: `RoomSpeechCreateRequest`, `RoomSpeechItem`, `RoomSpeechSubmitResult`, `RoomSpeechDeleteResult` |
| `server/app/services/room_speech_service.py` | 비즈니스 로직: 내용 정규화·멤버십 검증·in-memory rate limit(10s)·`next_cutoff_at` TTL·upsert·idempotent delete |
| `server/app/routers/room_speech.py` | `APIRouter`: GET/POST/DELETE `/challenges/{challenge_id}/room-speech` |
| `server/alembic/versions/20260419_0001_016_add_room_speech.py` | revision `016` (down_revision `015`): `room_speeches` 테이블, unique constraint, index 생성 |
| `server/tests/test_room_speech.py` | 12개 테스트 케이스 (전체 엔드포인트 + 엣지 케이스) |
| `server/app/models/__init__.py` | `RoomSpeech` import/export 추가 |
| `server/app/main.py` | `room_speech.router` 등록 |
| `server/app/utils/time.py` | `next_cutoff_at(cutoff_hour, now)` 헬퍼 추가 — 30초 경계 가드 포함 |

### Frontend

| 파일 | 목적 |
|------|------|
| `app/lib/features/challenge_space/models/room_speech.dart` | freezed + json_serializable `RoomSpeech` 모델 (~50줄) |
| `app/lib/features/challenge_space/api/room_speech_api.dart` | dio 기반 GET/POST/DELETE 래퍼 (~60줄) |
| `app/lib/features/challenge_space/providers/room_speech_provider.dart` | `RoomSpeechController` + `roomSpeechProvider(challengeId)` + round-robin 큐 로직 (~160줄) |
| `app/lib/features/challenge_space/widgets/speech_bubble.dart` | `SpeechBubble` 위젯 + 꼬리 `CustomPaint` + 애니메이션 래퍼 (~110줄) |
| `app/lib/features/challenge_space/widgets/speech_input_sheet.dart` | 롱-프레스 진입 바텀시트, 40자 카운터, 말하기/지우기 버튼 (~140줄) |
| `app/lib/features/challenge_space/widgets/room_character.dart` | `speechText`, `bubbleOpacity`, `bubbleScale` props 추가; `onLongPress` 연결 (수정) |
| `app/lib/core/widgets/challenge_room_scene.dart` | `RoomSpeechController` 생성·dispose, 각 `RoomCharacter`에 active state 분배 (수정) |
| `app/lib/features/challenge_space/screens/challenge_space_screen.dart` | 진입 시 `roomSpeechProvider(id).notifier.hydrate()` 호출 (수정) |
| `app/test/features/challenge_space/widgets/speech_bubble_test.dart` | golden + interaction 5개 테스트 |

## DB Schema

테이블: `room_speeches`

| 컬럼 | 타입 | 비고 |
|------|------|------|
| `id` | uuid | PK |
| `challenge_id` | uuid | FK → `challenges` |
| `user_id` | uuid | FK → `users` |
| `content` | varchar(40) | NOT NULL, trim, no newline |
| `created_at` | timestamptz | default now() |
| `expires_at` | timestamptz | NOT NULL |

제약:
- `UNIQUE (challenge_id, user_id)` — 재전송 시 upsert (content + created_at + expires_at 갱신)
- `INDEX (challenge_id, expires_at)` — 만료 필터링 속도 확보
- Migration revision: `016`

## API Surface

| 메서드 | 경로 | 설명 |
|--------|------|------|
| GET | `/api/v1/challenges/{challenge_id}/room-speech` | 해당 챌린지의 미만료 발언 목록 반환 (멤버 전용) |
| POST | `/api/v1/challenges/{challenge_id}/room-speech` | 내 발언 등록/갱신 (upsert) |
| DELETE | `/api/v1/challenges/{challenge_id}/room-speech` | 내 활성 발언 삭제 (idempotent) |

에러 코드:

| 코드 | HTTP | 조건 |
|------|------|------|
| `SPEECH_EMPTY` | 422 | trim 후 빈 문자열 |
| `SPEECH_TOO_LONG` | 422 | content > 40자 |
| `SPEECH_NOT_MEMBER` | 403 | 해당 챌린지 멤버 아님 |
| `SPEECH_RATE_LIMITED` | 429 | 10초 이내 동일 유저 재전송 |

## Key Design Decisions

- **In-memory rate limit**: 단일 워커 MVP. `_rate_cache: dict[str, datetime]` 모듈 수준 딕셔너리. 멀티 워커 배포 시 Redis 교체 필요.
- **30초 경계 가드**: `next_cutoff_at` 계산 시 cutoff 직전 30초 이내 입력은 **다음 cutoff**로 분류 — 입력 직후 만료 방지.
- **단일 `Timer.periodic`**: `RoomSpeechController`에서 전체 큐를 하나의 타이머로 진행. 캐릭터별 개별 타이머 금지 (누수 위험).
- **하얀 말풍선 고정**: `Colors.white` — 다크 모드에서도 유지. 텍스트는 `Color(0xFF212121)` 고정으로 대비 확보.
- **롱-프레스 600ms**: 기존 탭 인터랙션(👋/콕찌르기)과 충돌하지 않도록 `RawGestureDetector(LongPressGestureRecognizer)` 사용.
- **round-robin 인터럽트 없음**: 새 메시지 수신 시 현재 턴 종료 후 queue 뒤에 삽입. 발화 중간 끊김 없음.

## Out of Scope (Deferred)

- `VisibilityDetector` offstage pause — 스크롤로 씬이 화면 밖일 때 타이머 일시정지 (현재 AppLifecycleState만 처리)
- Redis 기반 rate limit — 멀티 워커 배포 시 필요
- WebSocket / SSE 실시간 동기화 — 60초 polling으로 MVP 충분
- 욕설·스팸 필터 — 별도 차단/신고 스펙에서 처리
- `api-contract.md`, `domain-model.md`, `prd.md` 갱신 — 사용자 승인 후 별도 작업

## Tests Added

- `server/tests/test_room_speech.py` — 12개 케이스: POST 정상·빈값·초과·줄바꿈제거·비멤버·레이트리밋·upsert, GET 목록·만료제외·비멤버, DELETE 삭제·idempotent
- `app/test/features/challenge_space/widgets/speech_bubble_test.dart` — 5개 케이스: 위젯 렌더·롱프레스→시트·3회반복·opacity 애니메이션·접근성

## QA Verdict

complete — 백엔드 12/12, 전체 suite 107/107. 프론트 5/5 + 전체 36/36. `flutter analyze` 0 errors.

## Deploy Verification

- Backend health: 200 OK (`/health`)
- Alembic revision `016` 적용 확인, `room_speeches` 테이블 postgres 확인
- Smoke endpoint: `GET /api/v1/challenges/.../room-speech` → 401 (인증 필요, 라우트 등록 확인)
- Simulator: running (iPhone 시뮬레이터 앱 기동 확인)
- Screenshots: `docs/reports/screenshots/2026-04-19-feature-room-speech-01.png` (로그인 화면 — 앱 정상 부팅 확인)

## Rollback Hints

삭제할 파일:
- `server/app/models/room_speech.py`
- `server/app/schemas/room_speech.py`
- `server/app/services/room_speech_service.py`
- `server/app/routers/room_speech.py`
- `server/alembic/versions/20260419_0001_016_add_room_speech.py`
- `server/tests/test_room_speech.py`
- `app/lib/features/challenge_space/models/room_speech.dart`
- `app/lib/features/challenge_space/api/room_speech_api.dart`
- `app/lib/features/challenge_space/providers/room_speech_provider.dart`
- `app/lib/features/challenge_space/widgets/speech_bubble.dart`
- `app/lib/features/challenge_space/widgets/speech_input_sheet.dart`
- `app/test/features/challenge_space/widgets/speech_bubble_test.dart`

되돌릴 파일 (부분 수정):
- `server/app/models/__init__.py` — `RoomSpeech` import 제거
- `server/app/main.py` — `room_speech.router` 등록 제거
- `server/app/utils/time.py` — `next_cutoff_at` 헬퍼 제거
- `app/lib/features/challenge_space/widgets/room_character.dart` — speech props 제거, `onLongPress` 제거
- `app/lib/core/widgets/challenge_room_scene.dart` — `RoomSpeechController` 생성·dispose 제거
- `app/lib/features/challenge_space/screens/challenge_space_screen.dart` — hydrate 호출 제거

Migration rollback:
```bash
cd server && uv run alembic downgrade -1   # 016 → 015, room_speeches 테이블 DROP
```

## Post-Implementation Debugging Journey (PR #13–#27 + cleanup)

초기 구현 (PR #12) 후 사용자 검증 단계에서 후속 PR 들을 통해 다음 root cause 들이 순차로 드러남. 같은 함정을 다음 슬라이스에서 피하기 위해 기록.

### PR #13 — RawGestureDetector long-press wrap 실패
- 시도: 캐릭터 long-press 600ms 로 SpeechInputSheet 진입
- 증상: 무반응
- 원인 (추정): inner `TappableCharacter` 의 GestureDetector(opaque) 가 long-press 가로챔
- 수정: 단순 `GestureDetector` + `onLongPress` (500ms 기본 duration 수용)

### PR #14 — `_speechParams` 초기화 race condition
- 증상: 여전히 무반응
- 원인: `_initSpeech` 가 `initState` 에서만 실행 → 첫 빌드에 `currentUserId == null` 이면 `_speechParams` 영원히 null → `onLongPress` 콜백 자체가 등록 안 됨
- 수정: `didUpdateWidget` 추가 + `onLongPress` wiring 의 `_speechParams` 의존 제거

### PR #15 — CANNOT_NUDGE_SELF fallback (디자인 무시한 UX 추가)
- 시도: tap 도 SpeechInputSheet 열도록 임의 추가
- 사용자 피드백: "꾹 누르는거랑 상관없이 인터페이스를 개선해 버렸어" — 디자인 갱신 무시
- 교훈: 디자인이 갱신 가능성이 있으면 임의 UX 추가 금지

### PR #17 — 디자인 갱신 반영: 카톡식 `SpeechInputBar`
- 디자인 갱신: long-press / 모달 / 바텀시트 모두 폐기, scene 직하부에 항상 보이는 한 줄 입력 바
- 캐릭터에 어떤 새 핸들러도 추가하지 않음 (이전 PR 들의 시도 모두 되돌림)
- 신규 `speech_input_bar.dart` + `MyActiveSpeechHint`, 삭제 `speech_input_sheet.dart`

### PR #19 — `myNickname` source 단일화
- 증상: 입력 바 탭 시 키보드 안 뜸
- 원인: `TextField.enabled = params != null` 인데 `params` 는 `myNickname` 이 null 이면 null. `myNickname` 을 `members` 에서 currentUserId 매칭으로 찾는데 매칭 실패 시 null. scene 의 `_initSpeech` 는 `'나'` fallback 있고 input bar 는 없어서 controller family key 가 두 곳 불일치 (controller 인스턴스 분리 부수 버그까지 동시 존재)
- 수정: `myNickname` 을 `authStateProvider.valueOrNull?.nickname ?? '나'` 단일 source 화. TextField 항상 enabled

### PR #21 — 전송 버튼 무반응 (탐색용)
- 가설 A: 텍스트 비어 onPressed null 로 회색 / 가설 B: 키보드가 입력 바를 덮어 탭 흡수
- 수정: `_onSendPressed` 항상 등록 (빈 텍스트면 hint + focus 복귀), Focus 시 `Scrollable.ensureVisible(alignment: 1.0)` 자동 스크롤

### PR #23 — `currentUserId` 진단 hint 추가
- 증상: 전송 시 `로그인이 필요해요` hint
- 원인 좁히기: `widget.currentUserId == null` 가 진짜 원인. auth 가 어디서 비는지 알아야 함
- 수정: `_resolveUserId` / `_resolveNickname` 헬퍼로 `ref.read(authStateProvider)` fresh 값 우선. params null 시 `AsyncValue` 의 정확한 상태(loading/error/data-null) 를 hint 노출

### PR #24 — **진짜 root cause #1**: `authStateProvider` autoDispose
- 진단 hint 결과: `로그인이 필요해요` (= `AsyncData(null)`, loading/error 아님)
- 원인: `@riverpod` 의 default 가 **autoDispose**. `AutoDisposeNotifierProvider` 가 my-page → 챌린지 방 navigation 사이 watcher 0 명이 되면 dispose → 챌린지 방에서 다시 watch 시 `build()` 가 초기값 `AsyncData(null)` 로 재생성 (devLogin 으로 set 한 user 손실)
- 영향 범위: Room Speech 만의 문제가 아니라 **챌린지 방 안의 모든 isSelf 판정**에 영향. 이전 디버깅에서 의심하던 "isSelf=false" 의 진짜 원인이기도 함
- 수정 (1줄): `@riverpod` → `@Riverpod(keepAlive: true)`. build_runner 재실행으로 `NotifierProvider` 변환

### PR #26 — **진짜 root cause #2**: `ResponseInterceptor` DioException wrap
- 증상: generic "전송 실패" 만 뜸 (어떤 ApiException code 매핑도 적중 안 함)
- 원인: `ResponseInterceptor.onError` (`api_client.dart:34-50`) 가 `ApiException` 을 새 `DioException.error` 안에 wrap. caller 는 **`on DioException catch` 후 `e.error` 를 unwrap** 해야 함. 현재 `_submit` 은 `on ApiException catch` 만 가져 모든 서버 에러가 generic catch 로 빠짐
- 수정: `_submit` / `_delete` 에 `on DioException catch` 추가, `_handleApiError` 헬퍼로 unwrap

### PR #27 — **진짜 root cause #3**: `expires_at` TIMESTAMP timezone 불일치
- 진단 hint 결과: `전송 실패 (HTTP 500)`. backend 로그:
  ```
  asyncpg.DataError: invalid input for query argument $5:
  datetime(...) (can't subtract offset-naive and offset-aware datetimes)
  SQL: $5::TIMESTAMP WITHOUT TIME ZONE
  ```
- 원인: `room_speeches.expires_at` 컬럼을 SQLAlchemy 모델에서 `Mapped[datetime]` 로만 선언 → SQLAlchemy default 인 `TIMESTAMP WITHOUT TIME ZONE` 으로 판단됨. 마이그레이션 016 은 `timezone=True` 로 만들었지만 모델이 안 맞춤. 다른 모델은 `created_at` 만 가지고 `server_default=func.now()` 로 서버측에서 생성하므로 같은 문제 안 났음
- SQLite 테스트는 tz 검증 안 함 → 12/12 통과로 검출 못 했음 (테스트 갭)
- 수정: `room_speech.py` 의 `created_at`, `expires_at` 모두 `TIMESTAMP(timezone=True)` 명시. 서비스의 `datetime.now().astimezone()` → `datetime.now(tz=KST)` 통일

### Final cleanup PR — 디버깅 잔재 정리
- PR #23 의 `_resolveUserId` / `_resolveNickname` 헬퍼 제거 (PR #24 keepAlive 로 race condition 사라짐 → widget prop 만으로 신뢰 가능)
- PR #21/#23 의 진단 hint (`로그인 정보 로딩 중`/`전송 실패: <CODE>`/`(HTTP $status)`) 를 친절한 표현으로 정리
- 기록: 본 섹션

## Lessons (다음 슬라이스 예방)

1. **Riverpod 전역 상태는 `keepAlive: true` 명시**. `@riverpod` default 는 autoDispose. auth, theme, app-wide settings 같은 lifetime-spanning 상태는 반드시 keepAlive
2. **dio + ResponseInterceptor 패턴**: 모든 caller 는 `on DioException catch` + `e.error is ApiException` unwrap. `on ApiException catch` 는 작동하지 않음. `member_nudge_list.dart:52-67` 검증된 패턴 참고
3. **PostgreSQL TIMESTAMPTZ 컬럼은 모델에서도 `TIMESTAMP(timezone=True)` 명시**. Python tz-aware datetime 을 직접 INSERT 하는 컬럼이면 필수. SQLite 테스트로는 검출 안 됨 → docker compose 로 실제 PG 통합 검증 필요
4. **디자인 미확정 시 임의 UX 개선 금지**. 디자인 워크플로우 갱신 먼저 확인
5. **단일 source 원칙**: 같은 정보(myNickname 등) 가 두 위젯에서 쓰이면 **같은 source** 에서 가져오기. 다르면 Riverpod family key 가 갈라져 별개 인스턴스 발생
6. **무반응 버그는 wiring 누락 가능성 우선 의심**. gesture/keyboard 같은 기술적 원인보다 callback 자체가 null 인 경우가 잦음. PR #14 / #24 / #26 모두 해당
