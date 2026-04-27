# 보석 페이지 (/gems) 구현

- **Date**: 2026-04-27
- **Worktree (수행)**: `.claude/worktrees/feature` (worktree-feature)
- **Worktree (영향)**: feature 단독 (full-stack)
- **Role**: feature

## Request

> ok. 보석은 누르면 맨 위에 주기적으로 사용자를 유도하기 위한 보물상자가 나오게 할거야. 보석상자를 열 시간이 지나면 열어서 보석 획득하라고 하고, 안지났으면 몇시간 남았다고 하고. 그리고 그 밑에는 이 앱의 재화인 보석을 구매할 수 이 있는 카드가 나오게 할거야. 보석 1000개당 5000원정도로 가격 매겨

## Root cause / Context

상단 `StatusBar` 의 gem pill (`💎 N`) 은 표시만 가능하고 탭 인터랙션이 없었다. (1) 일일 재방문을 유도할 daily-engagement 메커닉 부재, (2) 보석을 어떻게 모으는지 / 살 수 있는지 진입 지점 부재. streak 페이지 (commit `870a356`) 와 같은 패턴으로 gem pill 탭 → 풀스크린 페이지로 (a) 챌린지 인증 후 12h 타이머 보물상자 + (b) 3-tier 보석 팩 mock 구매 두 영역을 함께 제공.

## Actions

### 1. 사전 산출물

- 디자인 spec — `docs/superpowers/specs/2026-04-27-gems-page-design.md` (commit `c733b2e`)
- 구현 plan — `docs/superpowers/plans/2026-04-27-gems-page.md` (commit `01c534a`), 23-task TDD 사이클

### 2. 백엔드 (FastAPI + SQLAlchemy 2.0 async + Alembic)

| Commit | 변경 |
|---|---|
| `060ba22` | `server/alembic/versions/20260427_0001_022_add_user_treasure_states.py` — 신규 테이블 마이그레이션 (user_id PK, armed_date, armed_at, opened, updated_at) |
| `7791cb1` | `server/app/models/user_treasure_state.py` — SQLAlchemy 모델 + conftest.py import (테스트 DB 테이블 생성용) |
| `54309ce` | `server/app/schemas/treasure_chest.py` — `ChestState` enum (4 종) + `TreasureChestResponse` / `OpenChestResponse`. `server/app/schemas/gem_pack.py` — `GemPack` / `GemPacksResponse` / `PurchaseResponse` |
| `9b48ae0` | `server/app/services/gem_pack_catalog.py` — 3 tier 상수 catalog (pack_small/medium/large) |
| `030231b` | `server/app/services/treasure_chest_service.py` — `get_state(user_id)` state machine (5 케이스 RED→GREEN) |
| `23a7d87` | `arm_if_first_today(user_id, now)` 추가 (3 멱등성 테스트) |
| `d08cd88` | `open_chest(user_id)` 추가 — 100보석 award + 409 CHEST_NOT_READY/CHEST_ALREADY_OPENED (4 테스트) |
| `c90aca2` | `server/app/services/gem_pack_service.py` — `purchase(user_id, pack_id)` (mock, 영수증 검증 X) + 404 PACK_NOT_FOUND (3 테스트) |
| `8213bd2` | `server/app/routers/gems.py` — 4 엔드포인트 (GET /gems/chest, POST /gems/chest/open, GET /gems/packs, POST /gems/packs/{id}/purchase) + main.py 등록 + 7 통합 테스트 |
| `839105c` | `server/app/services/verification_service.py` — `arm_if_first_today` 호출 추가 (인증 시 chest arm), 1 통합 테스트 |
| `1143c74` | `docs/api-contract.md` 섹션 7 추가 (4 엔드포인트 + state 4종 + 에러 코드) |

총 신규 backend 테스트: **20** (treasure_chest 16 + gem_packs 4 + verification arm 1, 단순 합산은 20 이지만 일부 endpoint 테스트는 `verification arm` 측정 결과에 1 포함). 실제 pytest 실행 시: `tests/test_treasure_chest.py` 16 + `tests/test_gem_packs.py` 7 = **23 신규 테스트 모두 PASS**.

### 3. 프론트엔드 (Flutter + Riverpod + GoRouter + freezed + flutter_svg)

| Commit | 변경 |
|---|---|
| `51f5b6f` | `app/assets/icons/{chest_locked,chest_ready,chest_opened}.svg` — 3 chest 상태 SVG (회색/금색/체크) |
| `e54470b` | `app/lib/features/gems/models/{chest_state,treasure_chest,gem_pack,purchase_result}.dart` — enum + 3 freezed |
| `a5fa477` | `app/lib/features/gems/providers/{treasure_chest,gem_packs}_provider.dart` — FutureProvider.autoDispose + FutureProvider |
| `3cd5c70` | `app/lib/features/gems/widgets/treasure_chest_card.dart` — 4 state 분기 (no_chest / locked / openable / opened) + 5 위젯 테스트 |
| `0eba704` | `app/lib/features/gems/widgets/gem_pack_card.dart` — 1 pack 카드 (보석 + 보너스 + 가격 + 구매 버튼) + 3 위젯 테스트 |
| `f1aaf78` | `app/lib/features/gems/screens/gems_screen.dart` — 풀스크린 + chest + packs 통합 + onOpen/onPurchase 핸들러 |
| `d267069` | `app/lib/app.dart` — `/gems` GoRoute 추가 |
| `f5f2dce` | `app/lib/features/status_bar/widgets/status_bar.dart` — gem pill 만 InkWell 로 감싸 `context.push('/gems')`. streak pill 패턴과 동일. + 1 신규 tap 테스트 |
| `6c36b99` | `app/lib/features/gems/widgets/gem_pack_card.dart` 단순화 — iOS simulator 검증 중 Card+Wrap+ElevatedButton 조합이 layout 실패로 렌더 안됨. Container+BoxShadow + 단일 Text + compact 버튼 으로 fix |

총 신규 frontend 테스트: **9** (TreasureChestCard 5 + GemPackCard 3 + StatusBar gem tap 1) — 모두 PASS.

### 4. 통합 검증

- Docker compose rebuild + `/health` → 200 OK + alembic upgrade head → `022 (head)`
- pytest streak_calendar (9) + treasure_chest (16) + gem_packs (7) + 사전 결함 무관 = **169 passed** (TestSignature 6 deselect)
- flutter test: 신규 9 테스트 + 사전 결함 무관 = **136 passed / 7 failed** (사전 결함은 emoji 5 + profile_setup mock 1 + step1 1)
- iOS simulator clean install → 4단계 시각 검증 모두 통과

## Verification

### 백엔드

```
$ cd server && .venv/bin/python -m pytest tests/test_treasure_chest.py tests/test_gem_packs.py -v
... 23 passed in 0.48s

$ docker compose up --build -d backend && curl -fsS http://localhost:8000/health
{"status":"ok"}
$ docker compose exec backend uv run alembic current
022 (head)
```

### 프론트엔드

```
$ flutter test test/features/gems/ test/features/status_bar/widgets/status_bar_test.dart --plain-name "tapping"
TreasureChestCard 5 + GemPackCard 3 + StatusBar tap 2 (streak + gem) = 10 passed

$ dart analyze lib/features/gems/ test/features/gems/
No issues found!
```

### 시뮬레이터 시각 검증 (iPhone 17 Pro, iOS 26.4)

| # | 시나리오 | 스크린샷 | 결과 |
|---|---------|---------|------|
| 1 | 앱 launch → 내 페이지, status bar gem pill (💎 160) 보임 | `2026-04-27-feature-gems-page-01-launch.png` | ✅ |
| 2 | gem pill 탭 → /gems 진입 — AppBar "보석" + 보물상자 카드 (no_chest "오늘 챌린지를 인증하면…") + 3 팩 카드 (1,000원 / 5,000+500보너스 25,000원 / 12,000+2,000보너스 60,000원) + [구매] | `2026-04-27-feature-gems-page-02-after-tap.png` | ✅ |
| 3 | pack_small [구매] 탭 → snackbar "1000보석 충전 완료 (잔액 1160)" 표시 | `2026-04-27-feature-gems-page-03-after-purchase.png` | ✅ |
| 4 | 뒤로가기 → 내 페이지 복귀 + status bar gem 갱신 (160 → 1160) | `2026-04-27-feature-gems-page-04-back-to-my-page.png` | ✅ |

(테스트 데이터에 챌린지 미인증 상태이므로 보물상자는 `no_chest` 상태로 검증됨. 다른 3 state — locked / openable / opened — 는 TreasureChestCard 위젯 테스트 + treasure_chest_service backend 테스트로 검증.)

## Follow-ups

- **챌린지 (lightning) pill 탭 페이지** — 마지막 남은 status bar pill. streak/gem 과 같은 패턴으로 추후 확장.
- **실제 IAP 결제** — 현재 mock. App Store Connect / Google Play Billing 연동 필요. P1 후속.
- **chest 실시간 카운트다운 UI** — 현재 정적 표시. `Timer.periodic(1초)` 로 실시간 표시는 추후.
- **chest 멱등성** (transaction id) — purchase mock 은 사용자가 두 번 누르면 두 번 지급. 실제 IAP 전환 시 idempotency key 추가 필요.
- **GemPackCard 디자인 polish** — 현재 단순화 fix 후 동작 OK 이지만, 디자인 측면에서 보너스 배지 시각적 강조 / 가격 위계 등 ui-designer 검토 여지.
- **사전 결함 (이번 작업 무관)** — flutter test 사전 결함 7개 (status_bar emoji 5 + profile_setup mock 1 + challenge_create_step1 1), backend `TestSignature` 6개 — 별도 정리 필요.

## 디버그 노트 (GemPackCard layout 이슈)

iOS simulator 검증 중 첫 GemPackCard 디자인이 렌더되지 않는 문제 발생:
- 데이터는 정상 (FutureBuilder snapshot.data.length=3 확인)
- TreasureChestCard 는 정상 렌더
- 단순 `Container(height:60, color:Colors.lightBlue, child:Text)` 로 대체하면 정상 렌더
- 원인 추정: `Card` (theme cardColor + elevation) + `Row` 안의 `Expanded(Column(Wrap(...), Text))` + `ElevatedButton` 조합이 layout 계산 실패로 0-height 로 collapse
- Fix: `Card` → `Container(BoxShadow)`, `Wrap` 제거 (단일 Text 로 보석+보너스 합침), `ElevatedButton` 에 `tapTargetSize: shrinkWrap` + minimumSize 0 으로 compact

이 fix 는 GemPackCard 위젯 테스트 (3개) 를 그대로 통과 — 동작 contract 변경 없음.

## Related

- Spec: `docs/superpowers/specs/2026-04-27-gems-page-design.md`
- Plan: `docs/superpowers/plans/2026-04-27-gems-page.md`
- Streak page (같은 패턴): `docs/reports/2026-04-27-feature-streak-page.md` (PR #71)
- 신규 endpoint 4: `docs/api-contract.md` §7 Gems
- 신규 테이블: alembic migration 022
- 신규 모듈: `app/lib/features/gems/`, `server/app/services/{treasure_chest_service,gem_pack_catalog,gem_pack_service}.py`, `server/app/routers/gems.py`
