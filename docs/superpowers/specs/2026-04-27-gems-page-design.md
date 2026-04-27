# 보석 페이지 (Gems Page) 디자인

- 작성일: 2026-04-27
- 작성자: feature 워크트리 (auto)
- 상태: ready
- 범위: full-stack (Flutter + FastAPI + 신규 테이블 1)

## 1. 배경

상단 `StatusBar` 의 gem pill (`💎 N`) 은 표시만 가능하고 탭 인터랙션이 없다. 사용자가 보석을 어떻게 모으고 (chest 보상) / 어떻게 살 수 있는지 (in-app purchase) 진입 지점이 부재. 또한 일일 재방문을 유도할 daily-engagement 메커닉이 없다. 본 작업은 streak 페이지 (commit 870a356) 와 같은 패턴으로 gem pill 탭 → 풀스크린 페이지를 추가하면서, 페이지 안에 (a) 챌린지 인증 후 12h 타이머 보물상자 + (b) 3-tier 보석 팩 mock 구매를 함께 제공한다.

## 2. 사용자 흐름

```
StatusBar 노출 화면 (내 방 / 피드 / 설정 등)
    │  gem pill 탭
    ▼
/gems  보석 페이지
    ├─ 위: 보물상자 카드 (state 4종 분기)
    │     - openable 일 때: [100보석 받기] 탭 → award + state 전환
    └─ 아래: 보석 충전 카드 3개
          - [구매하기] 탭 → mock 결제 → balance 증가 + snackbar
    │  ← 뒤로가기
    ▼
이전 화면
```

## 3. 화면 구조

```
┌─────────────────────────────────┐
│ ←  보석                          │  AppBar
├─────────────────────────────────┤
│  ┌──────────────────────────┐   │
│  │ [chest icon]             │   │  보물상자 카드
│  │ [상태별 텍스트]           │   │
│  │ [상태별 CTA]              │   │
│  └──────────────────────────┘   │
├─────────────────────────────────┤
│  보석 충전                       │  section header
│  ┌──────────────────────────┐   │
│  │ 💎 1,000   5,000원       │   │  pack_small
│  │            [구매하기]      │   │
│  └──────────────────────────┘   │
│  ┌──────────────────────────┐   │
│  │ 💎 5,000 +500 보너스      │   │  pack_medium (10% bonus)
│  │            25,000원        │   │
│  │            [구매하기]      │   │
│  └──────────────────────────┘   │
│  ┌──────────────────────────┐   │
│  │ 💎 12,000 +2,000 보너스   │   │  pack_large (16% bonus)
│  │            60,000원        │   │
│  │            [구매하기]      │   │
│  └──────────────────────────┘   │
└─────────────────────────────────┘
```

### 3.1 보물상자 카드 4 state

| state | 아이콘 | 텍스트 | CTA |
|---|---|---|---|
| `no_chest` | `chest_locked.svg` (회색) | "오늘 챌린지를 인증하면\n보물상자가 열립니다" | (없음) |
| `locked` | `chest_locked.svg` | "X시간 Y분 남음" + LinearProgressIndicator | (비활성 "준비 중") |
| `openable` | `chest_ready.svg` (반짝) | "보물상자가 준비됐어요!" | **[100보석 받기]** ElevatedButton |
| `opened` | `chest_opened.svg` | "오늘 보상 받음. 내일 다시 인증!" | (없음) |

`remaining_seconds` 는 fetch 시점 기준 정적 표시. 실시간 카운트다운은 MVP 비범위 (사용자가 화면 머무르는 동안 시간이 줄어드는 시각 효과는 추후).

## 4. 백엔드

### 4.1 신규 테이블: `user_treasure_states`

| 컬럼 | 타입 | 설명 |
|---|---|---|
| `user_id` | UUID PK FK→users.id | 유저 1명당 1행 |
| `armed_date` | DATE NOT NULL | 마지막으로 chest 가 트리거된 날짜 (서버 timezone) |
| `armed_at` | TIMESTAMPTZ NOT NULL | 트리거 정확한 시각 |
| `opened` | BOOLEAN NOT NULL DEFAULT false | 오늘 chest 열었는가 |
| `updated_at` | TIMESTAMPTZ NOT NULL DEFAULT now() | 마지막 수정 시각 |

Alembic migration 신규 추가. 기존 `gem_transactions` 테이블은 그대로 사용 (보상 / 구매 모두 record, `reason` 으로 구분: `treasure_chest` / `purchase_mock`).

### 4.2 신규 엔드포인트

#### `GET /gems/chest` — 보물상자 상태 조회

**Response (200):**
```json
{
  "data": {
    "state": "locked",
    "armed_at": "2026-04-27T09:00:00Z",
    "openable_at": "2026-04-27T21:00:00Z",
    "opened_at": null,
    "reward_gems": 100,
    "remaining_seconds": 19380
  }
}
```

**state 결정 (`treasure_chest_service.get_state(user_id)`):**

```
row = user_treasure_states.get(user_id)
if row is None or row.armed_date != today:
    state = "no_chest"
elif row.opened:
    state = "opened"
elif now < row.armed_at + 12h:
    state = "locked"
else:
    state = "openable"
```

`reward_gems` 는 항상 100 (상수). 다른 필드는 state 에 따라 채움/null.

| state | armed_at | openable_at | opened_at | remaining_seconds |
|---|---|---|---|---|
| `no_chest` | null | null | null | null |
| `locked` | row.armed_at | armed_at + 12h | null | (openable_at - now) 초 |
| `openable` | row.armed_at | armed_at + 12h | null | 0 |
| `opened` | row.armed_at | armed_at + 12h | row.updated_at | null |

#### `POST /gems/chest/open` — 보물상자 열기

- state 검증 → openable 가 아니면:
  - locked / no_chest → `409 CHEST_NOT_READY` (message: "보물상자가 아직 준비되지 않았습니다.")
  - opened → `409 CHEST_ALREADY_OPENED` (message: "오늘 보물상자를 이미 열었습니다.")
- 정상: `gem_service.award_gems(user_id, 100, reason="treasure_chest")`, `user_treasure_states.opened = true`
- **Response (200):**
  ```json
  { "data": { "reward_gems": 100, "balance": 260, "opened_at": "2026-04-27T21:30:12Z" } }
  ```

#### `GET /gems/packs` — 구매 가능 보석 팩 목록

- 백엔드 상수 catalog (`server/app/services/gem_pack_catalog.py`) 에서 반환
- 카탈로그 변경 시 클라 업데이트 불필요

**Response (200):**
```json
{
  "data": {
    "packs": [
      { "id": "pack_small",  "gems": 1000,  "bonus_gems": 0,    "price_krw": 5000  },
      { "id": "pack_medium", "gems": 5000,  "bonus_gems": 500,  "price_krw": 25000 },
      { "id": "pack_large",  "gems": 12000, "bonus_gems": 2000, "price_krw": 60000 }
    ]
  }
}
```

#### `POST /gems/packs/{pack_id}/purchase` — 보석 팩 구매 (mock)

- pack_id 가 catalog 에 없으면 `404 PACK_NOT_FOUND`
- 결제 검증 없이 즉시 `award_gems(amount=pack.gems + pack.bonus_gems, reason="purchase_mock", reference_id=null)`
- **Response (200):**
  ```json
  { "data": { "awarded_gems": 5500, "balance": 5760, "pack_id": "pack_medium" } }
  ```
- 추후 실제 IAP 전환 시 본 엔드포인트 시그니처 유지 + Apple/Google `receipt_data` 필드만 추가하면 frontend 영향 0.

### 4.3 인증 시 chest arm 훅

`server/app/services/verification_service.create_verification` 의 성공 경로 끝 (transaction commit 직전) 에:

```python
await treasure_chest_service.arm_if_first_today(db, user_id, now)
```

**`arm_if_first_today(db, user_id, now)` 로직:**

```
row = user_treasure_states.get(user_id)
today = now.date()
if row is None:
    INSERT (user_id, today, now, false)
elif row.armed_date != today:
    UPDATE armed_date=today, armed_at=now, opened=false
else:
    pass  # 같은 날 추가 인증 — no-op (멱등)
```

### 4.4 Service 위치

- 신규: `server/app/services/treasure_chest_service.py` — `get_state`, `arm_if_first_today`, `open_chest`
- 신규: `server/app/services/gem_pack_catalog.py` — 상수 catalog + helper (`list_packs`, `get_pack(id)`)
- 신규: `server/app/services/gem_pack_service.py` — `purchase(pack_id, user_id)` (catalog lookup + award_gems)
- 신규: `server/app/routers/gems.py` — 4 엔드포인트
- 변경: `server/app/services/verification_service.py` — `arm_if_first_today` 호출 추가
- 변경: `server/app/main.py` — `gems` 라우터 등록

### 4.5 Schema

`server/app/schemas/treasure_chest.py`:
- `ChestState` enum (`no_chest`, `locked`, `openable`, `opened`)
- `TreasureChestResponse`
- `OpenChestResponse`

`server/app/schemas/gem_pack.py`:
- `GemPack` (id, gems, bonus_gems, price_krw)
- `GemPacksResponse`
- `PurchaseResponse`

## 5. 프론트엔드

```
app/lib/features/gems/
├── models/
│   ├── chest_state.dart            # enum ChestState
│   ├── treasure_chest.dart         # freezed TreasureChest
│   ├── gem_pack.dart               # freezed GemPack
│   └── purchase_result.dart        # freezed PurchaseResult
├── providers/
│   ├── treasure_chest_provider.dart  # FutureProvider.autoDispose
│   └── gem_packs_provider.dart       # FutureProvider
├── screens/
│   └── gems_screen.dart            # 풀스크린
└── widgets/
    ├── treasure_chest_card.dart    # 4 state 분기
    └── gem_pack_card.dart          # 1 pack 카드

app/assets/icons/
├── chest_locked.svg
├── chest_ready.svg
└── chest_opened.svg
```

### 5.1 모델

```dart
enum ChestState {
  @JsonValue('no_chest') noChest,
  @JsonValue('locked') locked,
  @JsonValue('openable') openable,
  @JsonValue('opened') opened,
}

@freezed
class TreasureChest with _$TreasureChest {
  const factory TreasureChest({
    required ChestState state,
    @JsonKey(name: 'armed_at') DateTime? armedAt,
    @JsonKey(name: 'openable_at') DateTime? openableAt,
    @JsonKey(name: 'opened_at') DateTime? openedAt,
    @JsonKey(name: 'reward_gems') required int rewardGems,
    @JsonKey(name: 'remaining_seconds') int? remainingSeconds,
  }) = _TreasureChest;
  factory TreasureChest.fromJson(Map<String, dynamic> json) => _$TreasureChestFromJson(json);
}

@freezed
class GemPack with _$GemPack {
  const factory GemPack({
    required String id,
    required int gems,
    @JsonKey(name: 'bonus_gems') required int bonusGems,
    @JsonKey(name: 'price_krw') required int priceKrw,
  }) = _GemPack;
  factory GemPack.fromJson(Map<String, dynamic> json) => _$GemPackFromJson(json);
}

@freezed
class PurchaseResult with _$PurchaseResult {
  const factory PurchaseResult({
    @JsonKey(name: 'awarded_gems') required int awardedGems,
    required int balance,
    @JsonKey(name: 'pack_id') required String packId,
  }) = _PurchaseResult;
  factory PurchaseResult.fromJson(Map<String, dynamic> json) => _$PurchaseResultFromJson(json);
}
```

### 5.2 Provider

```dart
final treasureChestProvider = FutureProvider.autoDispose<TreasureChest>((ref) async {
  final dio = ref.watch(dioProvider);
  final r = await dio.get('/gems/chest');
  return TreasureChest.fromJson(r.data as Map<String, dynamic>);
});

final gemPacksProvider = FutureProvider<List<GemPack>>((ref) async {
  final dio = ref.watch(dioProvider);
  final r = await dio.get('/gems/packs');
  final data = r.data as Map<String, dynamic>;
  return (data['packs'] as List)
      .map((j) => GemPack.fromJson(j as Map<String, dynamic>))
      .toList();
});
```

- `treasureChestProvider` 는 `autoDispose` — 화면 진입할 때마다 fresh fetch (`remaining_seconds` stale 방지)
- `gemPacksProvider` 는 일반 — catalog 거의 안 바뀜

### 5.3 GemsScreen

```dart
class GemsScreen extends ConsumerWidget {
  Widget build(context, ref) {
    final chest = ref.watch(treasureChestProvider);
    final packs = ref.watch(gemPacksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('보석')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            chest.when(
              loading: () => const _ChestSkeleton(),
              error: (e, _) => _ChestError(error: e),
              data: (c) => TreasureChestCard(
                chest: c,
                onOpen: () => _handleOpen(context, ref),
              ),
            ),
            const Divider(),
            const Padding(padding: EdgeInsets.all(16),
              child: Align(alignment: Alignment.centerLeft,
                child: Text('보석 충전', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
            packs.when(
              loading: () => const Padding(padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Center(child: Text('충전 옵션 불러오기 실패: $e')),
              data: (list) => Column(children: list.map((p) =>
                GemPackCard(
                  pack: p,
                  onPurchase: () => _handlePurchase(context, ref, p),
                )).toList()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleOpen(BuildContext context, WidgetRef ref) async {
    final dio = ref.read(dioProvider);
    final r = await dio.post('/gems/chest/open');
    ref.invalidate(treasureChestProvider);
    ref.invalidate(userStatsProvider);  // 상단 status bar 갱신
    if (context.mounted) {
      final reward = (r.data as Map)['reward_gems'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${reward}보석 획득!')));
    }
  }

  Future<void> _handlePurchase(BuildContext context, WidgetRef ref, GemPack p) async {
    final dio = ref.read(dioProvider);
    final r = await dio.post('/gems/packs/${p.id}/purchase');
    final result = PurchaseResult.fromJson(r.data as Map<String, dynamic>);
    ref.invalidate(userStatsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.awardedGems}보석 충전 완료 (잔액 ${result.balance})')));
    }
  }
}
```

### 5.4 TreasureChestCard 위젯

state 별 분기 (3.1 표 참조). 시간 포맷:

```dart
String _formatRemaining(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0) return '${h}시간 ${m}분 남음';
  return '${m}분 남음';
}
```

### 5.5 GemPackCard 위젯

- 좌측: 보석 아이콘 + `gems` 숫자 (3 자리 콤마)
- bonus_gems > 0 → 그 옆 작게 "+N 보너스" badge
- 우측 하단: 가격 + [구매하기] ElevatedButton

### 5.6 StatusBar gem pill 변경

`status_bar.dart` 의 gem pill 만 streak pill 와 동일 패턴으로 `Material+InkWell` 래핑 → `context.push('/gems')`. 다른 pill (chal/streak) 그대로.

### 5.7 Router

`app/lib/app.dart` — `/streak` 옆에:

```dart
GoRoute(path: '/gems', builder: (c, s) => const GemsScreen()),
```

## 6. Edge cases

| 케이스 | 처리 |
|---|---|
| user_treasure_states 행 없는 신규 유저 | state="no_chest" |
| 어제 인증 후 오늘 안 들어옴 | 오늘 chest = no_chest. 다음 인증 시 reset |
| 자정에 정확히 12h 도달 | armed_at + 12h ≤ now → openable. 같은 시각 비교는 `<=` 로 명시 |
| 같은 날 두 번 인증 | arm_if_first_today 가 멱등 — no-op |
| 인증 후 12h 안에 다른 챌린지 인증 | 마찬가지 no-op (이미 armed) |
| 시간대 차이 | 서버 timezone 단일 (KST) 가정 — MVP 한정 |
| 동시에 두 탭에서 open 시도 | DB row lock + opened=true 체크. 두번째 호출은 409 CHEST_ALREADY_OPENED |
| pack_id 변조 | catalog 에 없으면 404 PACK_NOT_FOUND |
| 음수 amount 시도 | 본 endpoint 는 amount 입력 받지 않음 (catalog 고정) — 안전 |
| 결제 mock 의 멱등성 | mock 이므로 멱등성 미보장. 사용자가 [구매하기] 두 번 누르면 두 번 지급. 실제 IAP 전환 시 transaction id 로 멱등성 확보 (P1) |

## 7. 테스트

### 7.1 백엔드 (`server/tests/test_treasure_chest.py`, `test_gem_packs.py`)

| 그룹 | 테스트 | 검증 |
|---|---|---|
| chest service | no_state_returns_no_chest | DB 행 없음 → state="no_chest" |
| | armed_today_locked | armed_at = now-5h, opened=false → state="locked", remaining ≈ 7h |
| | armed_today_openable | armed_at = now-13h, opened=false → state="openable" |
| | opened_today | opened=true, today → state="opened" |
| | armed_yesterday_returns_no_chest | armed_date=yesterday → state="no_chest" |
| | arm_if_first_today_inserts_row | 행 없음 + 호출 → INSERT |
| | arm_if_first_today_idempotent_same_day | 같은 날 재호출 → no-op |
| | arm_if_first_today_resets_after_day_change | armed_date=어제 + opened=true → UPDATE today, opened=false |
| chest endpoint | open_endpoint_openable_awards_gems | openable + POST → 200, balance += 100, opened=true |
| | open_endpoint_locked_returns_409 | locked → 409 CHEST_NOT_READY |
| | open_endpoint_already_opened_returns_409 | opened → 409 CHEST_ALREADY_OPENED |
| | open_endpoint_no_chest_returns_409 | no_chest → 409 CHEST_NOT_READY |
| | chest_endpoint_no_token_returns_401 | 토큰 없음 → 401 |
| verification 훅 | create_verification_arms_chest | 인증 생성 → user_treasure_states 행 arm |
| packs | packs_endpoint_returns_3_tiers | GET /gems/packs → 3 packs, 가격/보너스 일치 |
| | purchase_unknown_pack_returns_404 | invalid id → 404 PACK_NOT_FOUND |
| | purchase_small_pack_awards_1000_gems | pack_small → balance += 1000 |
| | purchase_medium_includes_bonus | pack_medium → balance += 5500 |
| | purchase_no_token_returns_401 | 토큰 없음 → 401 |

### 7.2 프론트엔드 (`app/test/features/gems/`)

| 파일 | 케이스 | 검증 |
|---|---|---|
| `treasure_chest_card_test.dart` | noChest 렌더 | "오늘 챌린지를 인증하면" 텍스트 |
| | locked + remainingSeconds=19380 | "5시간 23분 남음", LinearProgressIndicator 존재 |
| | openable | "준비됐어요!", "100보석 받기" ElevatedButton enabled |
| | openable + tap | onOpen 콜백 호출 |
| | opened | "오늘 보상 받음" 텍스트 |
| `gem_pack_card_test.dart` | bonus > 0 | "+500 보너스" 표시 |
| | tap [구매하기] | onPurchase 콜백 호출 |
| `status_bar_gem_tap_test.dart` | gem pill tap | mock GoRouter `/gems` push 검증 |

### 7.3 통합 검증

- `docker compose up --build -d backend && curl -fsS http://localhost:8000/health` → 200
- `pytest` 신규 ~19 테스트 + 사전 결함 무관 모두 통과
- `flutter test` 신규 8 테스트 + 사전 결함 무관 모두 통과
- iOS simulator clean install (terminate→uninstall→clean→pub get→build→install→launch)
- 시뮬레이터 시각 검증 (단계별 스크린샷 `docs/reports/screenshots/2026-04-27-feature-gems-page-{NN}.png`):
  1. 로그인 → 내 페이지 — status bar gem pill 보임
  2. gem pill 탭 → `/gems` 진입 — 보물상자 (현재 state) + 3 팩 카드 렌더
  3. (선택) 직접 DB 에 user_treasure_states 행 삽입 + armed_at = past 13h → 새로고침 후 openable state, [받기] 탭 → snackbar + state 전환
  4. pack_small [구매하기] 탭 → snackbar "1,000보석 충전 완료" + status bar gem 증가
  5. 뒤로가기 → 내 페이지 복귀, status bar gem 갱신 확인

## 8. 비범위 (Out of Scope)

- **실제 IAP 결제**: Apple App Store Connect / Google Play Billing — 별도 P1 작업. 본 작업은 mock 만.
- **실시간 카운트다운 UI**: `Timer.periodic(1초)` 로 화면 갱신. MVP 는 정적 표시 + pull-to-refresh.
- **결제 멱등성** (transaction id, idempotency key): 실제 IAP 전환 시 추가.
- **보석 사용처**: 기존 `/shop/items/{id}/purchase` 그대로. 본 작업은 보석 충전 흐름만 추가.
- **다른 chest 보상 (아이템 / 배지)**: chest 는 항상 100 보석. 추후 확장 여지.
- **chest 알림**: openable 도달 시 푸시 알림 — FCM P1 후속.

## 9. 위험 / 결정사항

- **Mock 결제의 부정 사용**: 사용자가 무한 호출하면 보석 무한 획득. 본 작업은 MVP / 내부 파일럿용이므로 OK. P1 IAP 전환 시 영수증 검증 필수.
- **시간대**: 서버 timezone (KST) 기준 단일. 해외 유저 / multi-region 은 비범위.
- **autoDispose 캐시 정책**: chest provider 는 autoDispose 로 화면 떠나면 cache 폐기. 화면 머무는 동안 stale (12h - 1초 계산이 안 맞을 수 있음). 사용자 pull-to-refresh 또는 새로 진입으로 해결.
- **chest 보상 100 고정**: 디자인 단순. 추후 streak 일수에 따라 보너스 등 확장 시 service 만 수정.

## 10. 참고

- `app/lib/features/status_bar/widgets/status_bar.dart` — gem pill 진입 트리거 추가 위치
- `app/lib/app.dart` — 라우트 추가
- `server/app/services/gem_service.py` — `award_gems` 재사용
- `server/app/services/verification_service.py` — `arm_if_first_today` 호출 위치
- `docs/superpowers/specs/2026-04-27-streak-page-design.md` — 같은 패턴 (gem pill 도 streak pill 와 동일 InkWell 패턴)
- `docs/api-contract.md` — `/gems/*` 엔드포인트 추가 필요
