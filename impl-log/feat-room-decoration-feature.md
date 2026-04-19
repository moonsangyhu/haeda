# feat: Room Decoration — Phase 1+2 (P2)

- **Date**: 2026-04-19
- **Type**: feat
- **Area**: both
- **Worktree**: feature (full-stack waiver — backend + frontend in same worktree)

## Requirement

디자인 워크트리(`docs/design/room-decoration.md`, status: ready)에서 미구현 상태로 남아 있던 방 꾸미기 기능을 구현. Phase 1(백엔드 풀세트) + Phase 2(미니룸 에디터 UI)를 먼저 완성하고, Phase 3~6는 후속 슬라이스로 유예.

- **Phase 1**: RoomItem 카탈로그, 장착 슬롯 관리, 챌린지 방 꾸미기, signature 슬롯 — 백엔드 전체
- **Phase 2**: 미니룸 에디터 화면 (내 방 전용), wall/floor variant 분기, GoRouter 통합, my_room FAB

## Plan Source

승인 계획: `~/.claude/plans/lucky-snuggling-boole.md` (레포 외부)

수락 기준:
- 신규 마이그레이션 `017` 적용, 시드 31 row 정상 삽입
- 5개 신규 엔드포인트 OpenAPI 노출 (`/me/room/miniroom`, `/me/room/miniroom/{slot}`, `/challenges/{challenge_id}/room`, `/challenges/{challenge_id}/room/{slot}`, `/challenges/{challenge_id}/room/signature`)
- `flutter build ios --simulator` 성공
- `flutter analyze` error 0
- `docker compose up --build -d backend` healthy

## Implementation

### Backend

| 파일 | 유형 | 설명 |
|------|------|------|
| `server/app/models/room_item.py` | NEW | SQLAlchemy 2.0 async 모델: `RoomItem` (카탈로그) |
| `server/app/models/miniroom_slot.py` | NEW | `MiniroomSlot` — 내 방 장착 슬롯 (user × slot_key, UNIQUE) |
| `server/app/models/challenge_room_slot.py` | NEW | `ChallengeRoomSlot` — 챌린지 방 장착 슬롯 (challenge × slot_key, UNIQUE) |
| `server/app/schemas/room_decoration.py` | NEW | Pydantic v2: 요청/응답 스키마 전체 |
| `server/app/services/room_decoration_service.py` | NEW | 비즈니스 로직: 아이템 소유 검증, 슬롯 upsert, signature 장착 |
| `server/app/routers/room_decoration.py` | NEW | 5개 엔드포인트 + APIRouter |
| `server/app/models/__init__.py` | MOD | `RoomItem`, `MiniroomSlot`, `ChallengeRoomSlot` export 추가 |
| `server/app/main.py` | MOD | `room_decoration.router` 등록 |
| `server/alembic/versions/20260419_0002_017_add_room_decoration.py` | NEW | revision `017` (down_revision `016`): 3개 테이블 + 인덱스 + 외래키 |
| `server/scripts/seed_room_items.py` | NEW | 시드 스크립트: 31 row (미니룸 8카테고리×2 + 챌린지 6카테고리×2 + SIGNATURE×3) |
| `server/tests/test_room_equip.py` | NEW | 장착 API 단위 테스트 (컨테이너 밖 호스트 환경에서 실행 필요) |

### Frontend

| 파일 | 유형 | 설명 |
|------|------|------|
| `app/lib/features/my_room/models/room_item.dart` | NEW | freezed + json_serializable `RoomItem` 모델 |
| `app/lib/features/my_room/api/room_decoration_api.dart` | NEW | dio 기반 5개 엔드포인트 래퍼 |
| `app/lib/features/my_room/providers/room_decoration_provider.dart` | NEW | `RoomDecorationController` — 슬롯 상태 + 장착/해제 액션 |
| `app/lib/features/my_room/screens/room_decorator_screen.dart` | NEW | 미니룸 에디터: 카테고리 탭, 아이템 그리드, 장착 버튼 |
| `app/lib/features/my_room/widgets/room_item_grid.dart` | NEW | 아이템 선택 그리드 위젯 |
| `app/lib/features/my_room/widgets/decoration_slot_preview.dart` | NEW | 슬롯 미리보기 오버레이 위젯 |
| `app/lib/core/widgets/miniroom_scene.dart` | MOD | wall + floor variant 분기 로직 추가 |
| `app/lib/features/my_room/screens/my_room_screen.dart` | MOD | FAB → `RoomDecoratorScreen` 진입 추가 |
| `app/lib/core/router/router.dart` | MOD | `/my-room/decorate` GoRouter 라우트 추가 |

### 소스오브트루스 문서 갱신

| 파일 | 변경 내용 |
|------|----------|
| `docs/prd.md` | F-31 Room Decoration 기능 항목 추가 (P2) |
| `docs/domain-model.md` | §2.10 RoomItem, §2.14 MiniroomSlot, §2.15 ChallengeRoomSlot, §2.16 RoomSignature 엔티티 추가 |
| `docs/api-contract.md` | §7 (내 방), §11 (챌린지 방) 신규 엔드포인트 5개 + 에러 코드 `ITEM_NOT_OWNED` 재사용 명시 |

## DB Schema

### Migration revision `017`

테이블 3개 신규 생성:

**room_items** (카탈로그)

| 컬럼 | 타입 | 비고 |
|------|------|------|
| `id` | uuid | PK |
| `key` | varchar(80) | UNIQUE |
| `category` | varchar(40) | miniroom / challenge / signature |
| `name` | varchar(80) | 한글 표시 이름 |
| `is_default` | boolean | default FALSE |
| `created_at` | timestamptz | server default |

**miniroom_slots** (내 방 장착)

| 컬럼 | 타입 | 비고 |
|------|------|------|
| `id` | uuid | PK |
| `user_id` | uuid | FK → users |
| `slot_key` | varchar(80) | 슬롯 식별자 (wall, floor, …) |
| `item_id` | uuid | FK → room_items |
| `equipped_at` | timestamptz | |
| UNIQUE | (user_id, slot_key) | |

**challenge_room_slots** (챌린지 방 장착)

| 컬럼 | 타입 | 비고 |
|------|------|------|
| `id` | uuid | PK |
| `challenge_id` | uuid | FK → challenges |
| `user_id` | uuid | FK → users |
| `slot_key` | varchar(80) | wall, floor, signature, … |
| `item_id` | uuid | FK → room_items |
| `equipped_at` | timestamptz | |
| UNIQUE | (challenge_id, user_id, slot_key) | |

### 시드 (`seed_room_items.py`) — 31 row

| 카테고리 | 수량 | 내용 |
|---------|------|------|
| miniroom/wall | 2 | COMMON_1, COMMON_2 (default) |
| miniroom/floor | 2 | COMMON_1, COMMON_2 (default) |
| miniroom/furniture | 2 | 기본 가구 |
| miniroom/window | 2 | 기본 창문 |
| miniroom/light | 2 | 기본 조명 |
| miniroom/plant | 2 | 기본 화분 |
| miniroom/rug | 2 | 기본 러그 |
| miniroom/decoration | 2 | 기본 소품 |
| challenge/wall | 2 | 챌린지 방 벽지 |
| challenge/floor | 2 | 챌린지 방 바닥재 |
| challenge/furniture | 2 | 챌린지 방 가구 |
| challenge/window | 2 | 챌린지 방 창문 |
| challenge/light | 2 | 챌린지 방 조명 |
| challenge/banner | 2 | 챌린지 방 현수막 |
| signature | 3 | 서명 스타일 3종 |
| **합계** | **31** | |

## API Surface

| 메서드 | 경로 | 설명 |
|--------|------|------|
| GET | `/api/v1/me/room/miniroom` | 내 방 슬롯 현황 조회 |
| PUT | `/api/v1/me/room/miniroom/{slot}` | 내 방 슬롯 장착/해제 |
| GET | `/api/v1/challenges/{challenge_id}/room` | 챌린지 방 슬롯 현황 조회 (내 것) |
| PUT | `/api/v1/challenges/{challenge_id}/room/{slot}` | 챌린지 방 슬롯 장착/해제 |
| PUT | `/api/v1/challenges/{challenge_id}/room/signature` | 챌린지 방 signature 슬롯 장착 |

에러 코드 재사용:

| 코드 | HTTP | 조건 |
|------|------|------|
| `ITEM_NOT_OWNED` | 403 | 소유하지 않은 아이템 장착 시도 |
| `CHALLENGE_NOT_FOUND` | 404 | 존재하지 않는 챌린지 |
| `NOT_MEMBER` | 403 | 챌린지 멤버 아님 |

## Key Design Decisions

- **`ITEM_NOT_OWNED` 재사용**: shop/item 시스템의 기존 에러 코드를 그대로 재사용. api-contract에 명시.
- **슬롯 upsert**: `ON CONFLICT (user_id, slot_key) DO UPDATE` 패턴 — 중복 INSERT 없이 단일 행 유지.
- **default 아이템 자동 장착**: 시드의 `is_default=True` 아이템을 `/me/room/miniroom` GET 시 미장착 슬롯에 자동 fallback 표시. DB 행은 생성하지 않음(뷰 레이어 처리).
- **Phase 1+2만 이번 사이클**: Phase 3(챌린지 방 UI), Phase 4(signature UI), Phase 5(보상 시스템), Phase 6(variant 콘텐츠 확장)는 후속.

## Tests Added

- `server/tests/test_room_equip.py` — 장착 PUT, 해제, 비소유 아이템 장착 시도(ITEM_NOT_OWNED), 비멤버 접근(NOT_MEMBER), 슬롯 upsert 검증. 컨테이너 밖 호스트 venv 미설정으로 본 사이클 실행 미수행. 후속 슬라이스에서 호스트 venv 셋업 후 실행 예정.

## QA Verdict

partial — 정적 검증(py_compile, flutter analyze) + 빌드(flutter build ios --simulator, docker compose backend rebuild) + OpenAPI 노출 + DB 마이그레이션/시드 통과. pytest 실행은 컨테이너 밖 호스트 환경 미셋업으로 미수행. 시뮬레이터 UI 인터랙션 수동 미검증.

## Deploy Verification

- Backend health: 200 OK (`/health`)
- Alembic revision `017` (head) 적용 확인
- 시드 31 row 삽입 확인 (카테고리별 분포 테이블 검증)
- 5개 신규 엔드포인트 OpenAPI `/docs` 노출 확인
- Simulator: running (iPhone 17 Pro, PID 42762, 앱 launch 성공)
- Screenshots: `docs/reports/screenshots/2026-04-19-feature-room-decoration-01.png`

## Rollback Hints

삭제할 신규 파일:

**서버**
- `server/app/models/room_item.py`
- `server/app/models/miniroom_slot.py`
- `server/app/models/challenge_room_slot.py`
- `server/app/schemas/room_decoration.py`
- `server/app/services/room_decoration_service.py`
- `server/app/routers/room_decoration.py`
- `server/alembic/versions/20260419_0002_017_add_room_decoration.py`
- `server/scripts/seed_room_items.py`
- `server/tests/test_room_equip.py`

**프론트**
- `app/lib/features/my_room/models/room_item.dart`
- `app/lib/features/my_room/api/room_decoration_api.dart`
- `app/lib/features/my_room/providers/room_decoration_provider.dart`
- `app/lib/features/my_room/screens/room_decorator_screen.dart`
- `app/lib/features/my_room/widgets/room_item_grid.dart`
- `app/lib/features/my_room/widgets/decoration_slot_preview.dart`

되돌릴 파일 (부분 수정):

- `server/app/models/__init__.py` — 3개 신규 모델 import 제거
- `server/app/main.py` — `room_decoration.router` 등록 제거
- `app/lib/core/widgets/miniroom_scene.dart` — wall/floor variant 분기 제거
- `app/lib/features/my_room/screens/my_room_screen.dart` — FAB 진입 코드 제거
- `app/lib/core/router/router.dart` — `/my-room/decorate` 라우트 제거

소스오브트루스 문서 롤백:
- `docs/prd.md` — F-31 항목 제거
- `docs/domain-model.md` — §2.10, §2.14~2.16 제거
- `docs/api-contract.md` — §7/§11 신규 엔드포인트 제거

Migration rollback:
```bash
cd server && uv run alembic downgrade -1   # 017 → 016, 3개 테이블 DROP
```

## Phase 3~6 후속 TODO

| Phase | 내용 | 우선순위 |
|-------|------|---------|
| Phase 3 | 챌린지 방 꾸미기 UI (ChallengeSpaceScreen) | P2 |
| Phase 4 | Signature 슬롯 UI | P2 |
| Phase 5 | 보상 시스템 연동 (챌린지 완료 시 아이템 지급) | P2 |
| Phase 6 | Variant 콘텐츠 확장 (계절 한정, 이벤트 아이템) | P2 |
