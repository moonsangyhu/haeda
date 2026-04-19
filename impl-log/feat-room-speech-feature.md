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
