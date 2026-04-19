---
slug: room-decoration
status: ready
created: 2026-04-19
area: full-stack
depends-on: miniroom-cyworld, challenge-room-social
---

# Room Decoration — Miniroom & Challenge Room Item System

## Overview

내 방(미니룸)과 챌린지 방에 **아이템을 교체하며 꾸미기**를 추가한다. 기존 캐릭터 장비 시스템(`Item` / `UserItem` / `CharacterEquip` / `shop` / `coin`)의 **확장**으로 설계하여 스키마·경제·UI를 최대한 재사용한다.

### 확정된 설계 축 (2026-04-19 사용자 결정)

| 축 | 결정 |
|----|------|
| 획득 | **상점(코인) + 달성 보상** 하이브리드 |
| 배치 | **슬롯별 variant 교체** (캐릭터 장비와 동일) — 드래그/그리드 배치 없음 |
| 챌린지 방 권한 | **방장 + 멤버 공존** — 방장은 공용 슬롯, 각 멤버는 자기 signature 슬롯 1개 |

### MVP 범위 밖

- 현재 `docs/prd.md` / `docs/domain-model.md` / `docs/api-contract.md` 에 없는 **P2 확장**.
- 실제 구현 전에 위 세 문서 갱신은 사용자 승인 필요 (본 문서는 제안).

## Design Concept

### Miniroom (개인 방) — 모든 슬롯을 본인이 꾸밈

```
 ┌──────────────────────────────────────┐
 │ [Wall]                  [Ceiling]    │  ← 1 슬롯: 벽지 변형
 │ ┌─────┐ 🕐         ╭─────╮           │  ← 1 슬롯: 시계·조명
 │ │[Win]│           │[Shlf]│           │  ← 1 슬롯: 창밖 풍경 / 선반
 │ └─────┘           ╰─────╯ 🌵[Plnt]   │  ← 1 슬롯: 화분
 │═════════════════════════════════════│
 │                                      │
 │   🖥️[Desk]                 😊        │  ← 1 슬롯: 책상 variant
 │   ╭─────────╮                        │
 │   │         │       [Rug]            │  ← 1 슬롯: 러그 pattern
 │   ╰─────────╯                        │
 │  [Floor pattern]                     │  ← 1 슬롯: 바닥 패턴
 └──────────────────────────────────────┘
```

8개 슬롯: **Wall / Ceiling / Window / Shelf / Plant / Desk / Rug / Floor**

### Challenge Room — 방장 공용 슬롯 + 멤버 signature 슬롯

```
 ┌──────────────────────────────────────┐
 │ [Wall]     ✨ 챌린지제목 ✨            │
 │ ┌───────┐ 🕐 ┌─────┐ ┌─────────┐    │
 │ │[Win] │     │[Cal] │ │[Board]  │    │  ← 공용 4: 창·달력·게시판·시계
 │ └───────┘    └─────┘ └─────────┘    │
 │═════════════════════════════════════│
 │  🎈       🐶       🌸       🏆      │  ← 멤버별 signature (캐릭터 옆)
 │   😊       😴      🎉        😤     │  ← 캐릭터들
 │  철수     영희     민수      지은      │
 │         ╭────────────╮               │
 │         │  [Sofa]    │               │  ← 공용 5: 중앙 소파/러그
 │         ╰────────────╯               │
 │  [Wood floor variant]                │  ← 공용 6: 바닥
 └──────────────────────────────────────┘
```

- **방장 공용 슬롯 6개**: Wall / Window / Mini-Calendar / Bulletin-Board / Sofa / Floor
- **멤버 signature 슬롯 1개 × N 멤버**: 각 캐릭터 옆 또는 위에 **작은 개인 아이템** 하나 (펫·풍선·화분·트로피·인형)
- 방장이 나가면(탈퇴) 공용 슬롯은 다음 최고 시니어 멤버에게 이관. MVP 에서는 방장 없으면 기본값으로 fallback.

## Slot Catalog

### Miniroom Slots (8)

| Slot Key | 의미 | 기본값 | 예시 변형 |
|----------|------|--------|-----------|
| `mr.wall` | 벽지 패턴·색 | Miniroom 기본 | 연노랑 / 라벤더 / 격자무늬 / 우주 |
| `mr.ceiling` | 천장 조명·몰딩 | 무등 | 펜던트 조명 / 별무리 / 샹들리에 |
| `mr.window` | 창밖 풍경 | 하늘 | 노을 / 밤하늘 / 바다 / 벚꽃 |
| `mr.shelf` | 선반 variant | 나무 2단 | 책장 / 진열장 / 공중 선반 |
| `mr.plant` | 화분 | 작은 화분 | 선인장 / 몬스테라 / 꽃다발 |
| `mr.desk` | 책상 variant | 평범한 책상 | 게이밍 데스크 / 서재 책상 / 다다미 좌식 |
| `mr.rug` | 러그 | 원형 러그 | 별 러그 / 체크 러그 / 구름 러그 |
| `mr.floor` | 바닥 패턴 | 체커보드 | 마루 / 타일 / 잔디 / 대리석 |

### Challenge Room Slots

**공용 (방장만 편집)**

| Slot Key | 의미 | 기본값 | 예시 변형 |
|----------|------|--------|-----------|
| `cr.wall` | 벽지 | 카테고리별 tint | 운동=초록 / 공부=파랑 / 습관=핑크 / 커스텀 |
| `cr.window` | 창밖 | 하늘 | 노을 / 밤하늘 |
| `cr.calendar` | 미니 달력판 variant | 기본 | 빈티지 / 네온 / 캐릭터 |
| `cr.board` | 게시판 variant | 코르크 | 자석 보드 / 화이트보드 / 스티커 보드 |
| `cr.sofa` | 중앙 모임 공간 | 원형 러그 | 소파 / 큰 쿠션 / 캠프파이어 |
| `cr.floor` | 바닥 | 나무 | 타일 / 잔디 / 대리석 |

**멤버 signature (각 멤버 본인이 선택)**

| Slot Key | 의미 | 기본값 | 예시 변형 |
|----------|------|--------|-----------|
| `cr.sig` | 캐릭터 옆 작은 아이템 | 없음 | 펫(강아지·고양이·햄스터) / 풍선 / 화분 / 트로피 / 인형 / 이모지 포스트잇 |

- signature 는 **내 캐릭터 옆 자동 배치** — 사용자가 위치를 지정하지 않음.
- 캐릭터 옆 8×8dp 영역에 표시. 크기 규격은 §Signature Placement 참고.

## Item Categories (Item.category 확장)

기존 5종(HAT/TOP/BOTTOM/SHOES/ACCESSORY)에 **ROOM_***계열을 추가:

```
MR_WALL / MR_CEILING / MR_WINDOW / MR_SHELF / MR_PLANT / MR_DESK / MR_RUG / MR_FLOOR
CR_WALL / CR_WINDOW / CR_CALENDAR / CR_BOARD / CR_SOFA / CR_FLOOR
SIGNATURE   // signature는 miniroom/challenge 양방 공용 (크로스 룸)
```

- 기존 `Item` 테이블에 `category` enum 확장, `sort_order`·`rarity` 그대로 사용.
- `SIGNATURE` 는 단일 카테고리이고 어디서든 등장 (개인 정체성 아이템).

## Acquisition Model

### 1. 코인 상점 (기존 확장)

- 기존 `GET /shop/items?category=MR_WALL` 처럼 카테고리 쿼리로 조회.
- 가격대 예시 (디자인 가이드, 최종 튜닝은 backend):
  - COMMON: 50–150 코인
  - RARE: 300–600 코인
  - EPIC: 1,000–2,000 코인 (상점 전용 + 제한된 수)
- 모든 `MR_*` / `CR_*` 는 상점 구매 가능. `CR_*` 는 방장 권한 체크 별도.

### 2. 챌린지 달성 보상 (신규)

| 달성 트리거 | 보상 |
|-------------|------|
| 첫 인증 완료 | Starter pack: `MR_WALL` COMMON 1개 + `MR_FLOOR` COMMON 1개 (랜덤) |
| 7일 연속 인증 (streak) | RARE 티어 `MR_PLANT` 1개 (랜덤) |
| 챌린지 완주 (30일) | EPIC 티어 `MR_*` 또는 `CR_*` 1개 (랜덤) + 기념 `SIGNATURE` (트로피) |
| 전원 인증 (올인증) | 방 구성원 전원에게 한정판 `SIGNATURE` (시즌별 변형) |
| 시즌 이벤트 | 한정판 아이템 (시즌 아이콘 기반) — 이벤트 기간 동안만 획득 |

- 보상 지급 경로: 서버 이벤트 발생 → `user_item` upsert + 토스트/모달 알림.
- **한정판 표식**: `Item.is_limited = true` flag + `obtained_at` 기록 — 상점 재구매 불가.

### 3. 기본 팩 (무료)

- 신규 가입 시 모든 기본값(`default` variant) 부여 — 사실상 소유 상태. 별도 item row 없이 null 허용으로 기본 렌더.

## Economy Guard Rails

- MVP: 챌린지 완주 보상으로 EPIC 획득 경로 확보 → 코인만으로 사기 어렵게 가격 책정.
- 상점 전면에 "상점 / 보상 안내" 탭 분리: 어떤 아이템이 상점 vs 보상인지 투명하게 표시.
- 보상 한정판: 구매 불가 + 자랑용 `is_limited` 배지 표시 (별 ✨).
- 인플레이션 방어: 하루 코인 획득량 상한은 기존 `gem_service` 정책 유지. 본 기능이 신규 코인 획득 경로를 추가하지 않음.

## Data Model Proposal

### 기존 테이블 수정

**`item`** — `category` enum 확장 (위 16종 + 기존 5종).

```sql
ALTER TYPE item_category ADD VALUE 'MR_WALL';
ALTER TYPE item_category ADD VALUE 'MR_CEILING';
-- ... (MR_*, CR_*, SIGNATURE)
```

추가 컬럼:
- `is_limited BOOLEAN DEFAULT FALSE`
- `reward_trigger VARCHAR` NULL (예: `FIRST_VERIFICATION`, `STREAK_7`, `COMPLETE_30`, `ALL_VERIFIED_DAY`, `SHOP`)
  - `SHOP` = 상점 판매 전용, `NULL` = 상점 판매 가능 + 보상 경로 병행 가능

### 신규 테이블

**`room_equip_mr`** — 유저의 미니룸 현재 장착 아이템

| Column | Type | Note |
|--------|------|------|
| user_id | uuid PK | FK → users |
| wall_item_id | uuid nullable | FK → item |
| ceiling_item_id | uuid nullable | |
| window_item_id | uuid nullable | |
| shelf_item_id | uuid nullable | |
| plant_item_id | uuid nullable | |
| desk_item_id | uuid nullable | |
| rug_item_id | uuid nullable | |
| floor_item_id | uuid nullable | |
| updated_at | timestamptz | |

**`room_equip_cr`** — 챌린지 방 공용 아이템 (방장 소유)

| Column | Type | Note |
|--------|------|------|
| challenge_id | uuid PK | FK → challenges |
| wall_item_id | uuid nullable | |
| window_item_id | uuid nullable | |
| calendar_item_id | uuid nullable | |
| board_item_id | uuid nullable | |
| sofa_item_id | uuid nullable | |
| floor_item_id | uuid nullable | |
| updated_by_user_id | uuid | FK → users (감사용) |
| updated_at | timestamptz | |

**`room_equip_cr_signature`** — 챌린지 방 멤버 signature

| Column | Type | Note |
|--------|------|------|
| id | uuid PK | |
| challenge_id | uuid | FK → challenges |
| user_id | uuid | FK → users |
| signature_item_id | uuid | FK → item (category = SIGNATURE) |
| updated_at | timestamptz | |

UNIQUE `(challenge_id, user_id)` — 챌린지당 멤버별 1건.

### 기본값 정책

- 테이블에 row 없거나 `*_item_id` NULL → 디자인 기본값 렌더.
- 아이템 삭제/비활성화(`is_active=false`) → NULL 로 자동 fallback.

## API Contract Proposal

> ⚠️ `docs/api-contract.md` 갱신은 별도 승인 필요.

### Shop (기존 확장)

- `GET /shop/items?category={cat}&rarity={rarity}&is_limited={bool}` — category 필터에 신규 값 허용.
- `POST /shop/items/{id}/purchase` — 기존 로직. 신규 category 도 동일 검증.

### Inventory

- `GET /me/items?category={cat}` — 내 소유 아이템 카테고리별 조회.

### Miniroom equip

- `GET /me/room/miniroom` → `{data: {wall_item_id, ceiling_item_id, ...}}`
- `PUT /me/room/miniroom` body `{wall_item_id?, ...}` → 슬롯별 부분 교체 (owned 검증 → 403 `NOT_OWNED`)
- `DELETE /me/room/miniroom/{slot}` → 해당 슬롯 기본값으로

### Challenge room equip (방장 전용)

- `GET /challenges/{id}/room` → `{data: {wall_item_id, ..., signatures: [{user_id, nickname, signature_item_id}]}}`
- `PUT /challenges/{id}/room` body `{wall_item_id?, ...}` → 방장만 호출 가능 (`CR_NOT_CREATOR` 403)
- `DELETE /challenges/{id}/room/{slot}` → 기본값

### Signature (멤버 본인)

- `PUT /challenges/{id}/room/signature` body `{signature_item_id}` → 본인 signature 지정
- `DELETE /challenges/{id}/room/signature` → 해제

### Rewards 지급

- 내부 서비스 훅: `award_reward(user_id, trigger)` — 트리거 발생 시 호출.
- 알림: 별도 `GET /me/rewards/unread` + `POST /me/rewards/{id}/acknowledge` (토스트·모달 표시 후 읽음 처리).
- 에러 코드:
  - `NOT_OWNED` 403 — 소유하지 않은 아이템을 장착 시도
  - `CR_NOT_CREATOR` 403 — 방장이 아닌 멤버가 공용 슬롯 편집 시도
  - `ITEM_CATEGORY_MISMATCH` 422 — 해당 슬롯 카테고리와 맞지 않는 아이템 지정
  - `REWARD_ALREADY_CLAIMED` 409 — 동일 trigger 로 이미 보상 지급됨

## UI Flow

### A. 인벤토리 / 상점 진입

- 기존 Character tab (`/app/lib/features/character/`) 옵션으로 **"내 방 꾸미기"** 엔트리 추가.
- 또는 미니룸 화면에서 "꾸미기" 연필 아이콘 탭 → `RoomDecoratorScreen` 진입.

### B. RoomDecoratorScreen (미니룸)

```
┌─────────────────────────────────────────┐
│ ← 내 방 꾸미기                  💰 1,230 │
├─────────────────────────────────────────┤
│                                         │
│   [Miniroom preview — 실시간 반영]        │  ← 현재 편집 중 반영
│                                         │
├─────────────────────────────────────────┤
│ [벽지][천장][창][선반][화분][책상][러그][바닥] │ ← 슬롯 탭 (수평 스크롤)
├─────────────────────────────────────────┤
│                                         │
│  (선택한 슬롯의 variant 그리드)            │
│  [기본]  [소유1]  [소유2]  [상점]  [보상]  │
│                                         │
│  [저장]                                 │
└─────────────────────────────────────────┘
```

- 상단: 미니룸 실시간 프리뷰 (선택 variant 즉시 반영, 저장 전까지는 local state).
- 중단: 슬롯 칩 리스트. 선택된 슬롯 하이라이트.
- 하단: 해당 슬롯 variant 그리드.
  - **소유 중**: 바로 선택 가능.
  - **상점**: 구매 모달 → 코인 차감 → 소유 상태.
  - **보상 한정판**: 소유 안 한 경우 회색 락 + "30일 완주 시 획득" 힌트.
- 저장: `PUT /me/room/miniroom` — 변경된 슬롯만 patch.

### C. RoomDecoratorScreen (챌린지 방)

- 동일 레이아웃, 단 상단에 **방장 배지** 표시.
- 방장 아닌 멤버가 진입: 공용 슬롯 chip 은 회색 + "방장만 편집 가능", signature 탭만 활성.
- signature 탭: 보유한 `SIGNATURE` 카테고리 아이템 중 하나 선택.

### D. 진입 동선

- 미니룸 → 우하단 연필 FAB → `RoomDecoratorScreen(roomType: miniroom)`
- 챌린지 방 (ChallengeSpaceScreen 상단 scene 의 우상단 연필 아이콘) → `RoomDecoratorScreen(roomType: challenge, id: xxx)`
- 챌린지 방 → 내 캐릭터 아래 "내 signature" 버튼 → `SignaturePickerSheet` (바텀시트만 열고 빠르게 선택)

## Pixel Art Style Guide

모든 신규 아이템 sprite 는 **기존 CustomPainter 패턴**을 따른다 (`character_avatar.dart`, `challenge_room_scene.dart` 참고).

### 공통 규칙

- 캔버스: 해당 슬롯 영역 bounding rect, logical grid 1dp = 1px.
- 컬러: `MiniroomColors` / `ChallengeRoomColors` 팔레트 **우선 재사용**. 신규 팔레트 필요 시 각 variant 도크에 명시.
- 그림자: `BoxShadow` 금지 — CustomPainter 로 1–2dp darker fill drawRect.
- 라인: 1dp 고정, anti-alias 끔 (`Paint()..isAntiAlias = false`) — 픽셀 느낌 유지.
- 투명 배경 허용 (PNG sprite 사용 시) — 단 MVP 는 procedural painter 권장.

### 슬롯별 크기 가이드 (32×24 grid 기준)

| Slot | 권장 영역 (cols × rows) | Notes |
|------|-----------------------|-------|
| wall | 32 × 12 | 반복 패턴, 전체 벽 tint |
| ceiling | 32 × 2 | 몰딩 라인 + 중앙 조명 4×2 |
| window | 6–8 × 5–6 | 액자 테두리 + 내부 풍경 |
| shelf | 6–8 × 3–5 | 선반 줄기 + 장식물 |
| plant | 3–4 × 3–5 | 화분 + 잎·꽃 |
| desk | 8 × 5–7 | 상판 + 다리 + 소품 |
| rug | 10–14 × 5 | 타원/사각, 중앙 문양 |
| floor | 32 × 12 | 반복 패턴 |
| calendar (CR) | 5 × 5 | 테두리 + 숫자 강조 |
| board (CR) | 10 × 7 | 프레임 + 내용물 |
| sofa (CR) | 16 × 5 | 등받이 + 쿠션 |
| signature | 4 × 4 | 캐릭터 옆, 초소형 |

### 레어도 시각 효과 (기존 캐릭터 장비 패턴 재사용)

- COMMON: 이펙트 없음
- RARE: 아이템 주변 2dp 미세 glow (낮은 opacity blue)
- EPIC: shimmer 애니메이션 (`character_avatar.dart`의 EPIC 로직 재활용)
- LIMITED (보상 한정판): ✨ 작은 스파클 1개 주기적 출현 + 이름 라벨 옆 ✨ 배지

### 스프라이트 제작 프로세스 (implementation 단계)

1. 본 문서의 슬롯별 크기 가이드에 맞춰 초안 그리드 확정.
2. `ui-designer` 에이전트가 도트 그래픽 20년 전문가 페르소나로 각 variant 스프라이트 디자인.
3. front 워크트리의 CustomPainter 구현체로 이식.
4. 프리뷰 화면에서 팔레트 충돌·가독성 검증.

## Signature Placement (Challenge Room)

- 캐릭터 배치 좌표 `(x, y)` 기준 우측 하단 오프셋 `(+size*0.35, +size*0.2)`.
- signature sprite 크기: `size * 0.35` (캐릭터 대비 1/3).
- z-order: floor 위, character 옆 (약간 뒤쪽).
- 캐릭터가 우측 벽 근처면 오프셋 좌측으로 mirror.
- 인증·미인증 상태 무관하게 표시 — 단, 미인증 캐릭터의 signature 는 opacity 0.7 로 톤 다운.

## Co-Decoration Rules (Challenge Room)

- 방장 변경: 챌린지 생성자 = 방장. 방장이 탈퇴하면 가장 오래된 남은 멤버가 자동 승계. MVP 에서는 승계 정책 간단히: `room_equip_cr.updated_by_user_id` 가 탈퇴한 경우 `null` 로 두고 기본값 렌더. 사용자 요구 시 승계 로직 정교화.
- 변경 알림: 방장이 공용 슬롯을 교체하면 멤버들에게 간단한 토스트 "방장이 방을 꾸몄어요 🎨" (선택적, Phase 2).
- 멤버 signature 변경: 조용히 반영, 알림 없음.
- 동시 편집 충돌: 방장이 2개 세션에서 편집 시 last-write-wins. ETag 같은 낙관적 락은 MVP 범위 밖.

## Edge Cases

| 상황 | 처리 |
|------|------|
| 보유 안 한 아이템 장착 시도 | 403 `NOT_OWNED`. 상점 모달 자동 오픈 옵션 제공. |
| 보유 아이템이 is_active=false 로 변경 | 해당 슬롯 기본값 렌더. 유저에게 silent fallback (정책 결정 필요). |
| 카테고리 불일치 장착 | 422 `ITEM_CATEGORY_MISMATCH`. |
| 방장 탈퇴 | 공용 슬롯 기본값 렌더, room_equip_cr row 유지 (이관 정책은 P3). |
| 멤버 탈퇴 | signature 해제. row 삭제. |
| 챌린지 삭제 | `room_equip_cr` + `room_equip_cr_signature` cascade 삭제. |
| 보상 트리거 이중 발급 | `(user_id, reward_trigger, reference_id)` unique 로 방지. |
| 신규 카테고리 배포 직후 legacy 클라이언트 | 알 수 없는 카테고리는 렌더 스킵 (graceful degradation). |
| 아이템 이미지 로드 실패 | 기본값 렌더 + 재시도 없음 (procedural 이므로 이론상 실패 없음). |
| 시즌 아이템 만료 | `obtained_at` 유지, 계속 장착 가능. 상점 재등장은 시즌 이벤트 재개 시. |

## Accessibility

- 슬롯 칩: `Semantics(label: '{슬롯명} 선택됨')` + focus highlight.
- variant 그리드: 각 아이템에 `Semantics(label: '{이름}, {희귀도}, {소유여부}')`.
- 색각 보조: 레어도 배지에 색 외에 **기호**(◇ COMMON, ◆ RARE, ★ EPIC, ✨ LIMITED) 병기.
- 다크 모드: 슬롯 칩·그리드는 테마에 맞춰 변경. 미니룸 내부 미리보기는 방 자체 색 그대로 (테마 무관).

## Architecture

### Backend (server/) — 신규/수정

| Path | 역할 |
|------|------|
| `server/app/models/item.py` | category enum 확장, is_limited/reward_trigger 컬럼 |
| `server/app/models/room_equip.py` | 3개 테이블 ORM (mr / cr / cr_signature) |
| `server/app/schemas/room_equip.py` | Pydantic v2 스키마 |
| `server/app/routers/room_equip.py` | GET/PUT/DELETE 라우터, 권한 체크 |
| `server/app/services/room_equip_service.py` | 장착·해제·카테고리 검증 |
| `server/app/services/reward_service.py` | 보상 트리거 발생 → user_item 지급, 이중 발급 방지 |
| `server/app/routers/shop.py` | category 필터 확장, is_limited 필터 |
| `server/alembic/versions/xxxx_room_decoration.py` | enum 확장 + 3 테이블 + 인덱스 |
| `server/tests/routers/test_room_equip.py` | 슬롯 장착/해제/권한/에러 |

### Frontend (app/) — 신규/수정

| Path | 역할 |
|------|------|
| `app/lib/features/room_decoration/` | 신규 feature 폴더 |
| `  models/room_equip.dart` | freezed 모델 |
| `  models/room_slot.dart` | slot enum + 메타데이터 |
| `  providers/room_equip_provider.dart` | Riverpod: 내 미니룸 / 챌린지 방 상태 |
| `  providers/reward_provider.dart` | 보상 수령 알림 state |
| `  screens/room_decorator_screen.dart` | 에디터 화면 (miniroom & challenge 공용) |
| `  widgets/slot_chip_row.dart` | 슬롯 선택 칩 리스트 |
| `  widgets/variant_grid.dart` | variant 그리드 (소유·상점·보상 배지) |
| `  widgets/signature_picker_sheet.dart` | 챌린지 방 signature 빠른 선택 |
| `  widgets/reward_popup.dart` | 보상 획득 모달 |
| `app/lib/core/widgets/character_avatar.dart` | EPIC shimmer 로직을 room item 에 재사용 |
| `app/lib/core/widgets/challenge_room_scene.dart` | 공용 슬롯 렌더 로직 확장 (variant 분기) |
| `app/lib/features/miniroom/...` (현재 파일들) | variant 분기 렌더 추가 |
| `app/lib/features/challenge_space/widgets/room_character.dart` | signature sprite 오버레이 추가 |

### QA

| Path | 역할 |
|------|------|
| `app/test/features/room_decoration/` | provider·screen·widget 단위 테스트 |
| `server/tests/routers/test_room_equip.py` | 라우터 통합 테스트 |
| `server/tests/services/test_reward_service.py` | 보상 트리거·중복 방지 |

## Implementation Priority

1. **Phase 1 — Backend skeleton**
   - `Item.category` 확장, 3개 테이블 추가, GET/PUT/DELETE 라우터.
   - 기본값 fallback 동작 확인. 스키마만 살아 있으면 기존 UI 변경 없이 테스트 가능.

2. **Phase 2 — Miniroom decorator UI**
   - `RoomDecoratorScreen` (miniroom 한정).
   - 기본 variant 2–3개만 먼저 도입 (wall, floor).
   - 상점 구매 flow 완성.

3. **Phase 3 — Challenge room 공용 슬롯**
   - 방장 권한 체크 + 공용 슬롯 UI.
   - 카테고리별 기본 variant 도입.

4. **Phase 4 — Signature 슬롯**
   - 멤버 signature 선택 시트 + 캐릭터 옆 렌더.
   - SIGNATURE 카테고리 첫 세트 (펫 3종, 화분 2종, 트로피 1종).

5. **Phase 5 — 보상 시스템**
   - `reward_service` 구현 + 알림 UI.
   - 트리거: FIRST_VERIFICATION, STREAK_7, COMPLETE_30 부터.

6. **Phase 6 — Variant 확장**
   - 각 슬롯당 COMMON 3–5개, RARE 2–3개, EPIC 1개 수준으로 콘텐츠 확보.
   - 한정판·시즌 이벤트 아이템.

## Out of Scope

- 드래그·자유 배치 (grid placement) — 본 디자인은 슬롯 교체 방식 고정.
- 아이템 거래·선물·교환 — 추후 별도 스펙.
- 방 공개·방문·방명록 — 추후 소셜 확장.
- 아이템 합성·진화 — 본 범위 아님.
- 시즌 순환 자동화 — 이벤트 타겟팅/스케줄러는 운영 툴 범위.
- 차단된 유저의 signature 숨김 — 차단 기능 자체가 MVP 범위 밖.

## Related

- `docs/design/miniroom-cyworld.md` — 미니룸 32×24 그리드, 기본 furniture layout, `MiniroomColors`.
- `docs/design/challenge-room-social.md` — 챌린지 방 캐릭터 배치 · `ChallengeRoomColors` · 공용 furniture.
- `docs/design/challenge-room-speech.md` — 같은 챌린지 방에 겹치는 말풍선 시스템. signature 배치와 z-order 충돌 주의 (signature 는 bubble 보다 z 낮음).
- `app/lib/features/character/` — 기존 shop / inventory / equip 패턴 (본 디자인의 템플릿).
- `app/lib/core/widgets/character_avatar.dart` — EPIC shimmer · CustomPainter 패턴.
- `server/app/models/item.py` · `user_item.py` · `character_equip.py` — 확장 대상 스키마.
- `server/app/services/shop_service.py` · `gem_service.py` — 경제 로직 재사용.
