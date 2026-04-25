# 상점 구매 시 상단 상태바 젬 잔액 갱신 누락 버그 수정

- Date: 2026-04-25
- Worktree (수행): feature
- Worktree (영향): feature (app/ 만)
- Role: feature

## Request

사용자 보고: "상점에서 물건을 사면 돈이 안 줄어들어. 이 버그 수정해 줘."

## Root cause / Context

systematic-debugging 4단계로 추적한 결과, **백엔드는 정상**이며 **프론트엔드의 캐시 invalidate 누락**이 원인이었다.

### 데이터 흐름

| 계층 | 동작 | 확인 |
|------|------|------|
| `server/app/services/shop_service.py:83-89` | `gem_service.award_gems(amount=-item.price, "PURCHASE")` 로 음수 GemTransaction 행 삽입 | ✓ 정상 |
| `server/app/services/gem_service.py:27-32` | `SUM(GemTransaction.amount)` 으로 잔액 계산 | ✓ 정상 |
| `server/app/routers/me.py:61-67` `/me/coins` | 위 SUM 반환 | ✓ 정상 |
| `server/app/services/user_stats_service.py:72` `/me/stats` | 동일 SUM 을 `gems` 필드에 반환 | ✓ 정상 |
| `app/lib/core/widgets/main_shell.dart:30-32` | `MainShell` 이 모든 메인 탭 위에 `StatusBar` 를 globally 마운트 | — |
| `app/lib/features/status_bar/widgets/status_bar.dart:12,75` | `StatusBar` 가 `userStatsProvider` 를 watch 해 `stats.gems` 표시 (사용자가 보는 "돈") | — |
| `app/lib/features/status_bar/providers/user_stats_provider.dart` | `FutureProvider` — invalidate 없으면 캐시 영구 유지 | — |
| `app/lib/features/character/providers/shop_provider.dart:64-69` (수정 전) | 구매 성공 후 `coinBalanceProvider` / `myItemsProvider` / `shopItemsProvider(*)` 만 invalidate. **`userStatsProvider` 누락** | ✗ 버그 |

### 결과로 드러난 사용자 증상

백엔드는 정확히 차감된 잔액을 반환하지만, 사용자가 실제로 보는 상단 상태바의 젬 숫자는 캐시된 옛 값이 그대로 유지되어 "돈이 안 줄어드는 것처럼" 보였다.

### 동일 시나리오의 working 패턴 (참조)

`app/lib/features/challenge_space/screens/create_verification_screen.dart:234` 는 인증 제출(젬 보상 발생) 직후 `ref.invalidate(userStatsProvider)` 를 호출. 상점만 같은 패턴이 빠져 있었다.

## Actions

1. **RED 테스트 작성** — `app/test/features/character/providers/shop_provider_test.dart`
   - `userStatsProvider` 의 fetch 호출 횟수를 카운트
   - 구매 전후 카운트 비교로 invalidate 여부 검증
   - 수정 전 결과: `Expected: <2>` / `Actual: <1>` — 가설대로 실패
2. **GREEN 수정** — `app/lib/features/character/providers/shop_provider.dart`
   - import 추가: `'../../status_bar/providers/user_stats_provider.dart'`
   - `purchaseItem` 의 success 분기에 `_ref.invalidate(userStatsProvider);` 한 줄 추가 (verification 흐름과 동일 패턴)
3. **검증** — 단위 테스트 GREEN, flutter analyze 0 issues, 캐릭터 도메인 테스트 3/3 PASS, iOS clean install + launch 성공

## Verification

| 항목 | 결과 | 비고 |
|------|------|------|
| 단위 테스트 (RED) | FAIL — `Expected: <2> Actual: <1>` | 가설 정확히 재현 |
| 단위 테스트 (GREEN) | PASS — `+1: All tests passed!` | 1줄 수정 후 |
| `flutter analyze` (변경 파일) | PASS — `No issues found! (ran in 1.3s)` | shop_provider.dart + 새 테스트 |
| `flutter test test/features/character/` | PASS — `+3: All tests passed!` | 회귀 없음 |
| `flutter test` (전체) | `+97 -7` — 7 pre-existing | stash 후 동일 실패 확인 — 본 변경과 무관 (status_bar SVG 마이그레이션 잔재) |
| `flutter clean && flutter build ios --simulator` | PASS — `✓ Built build/ios/iphonesimulator/Runner.app` (~26s) | clean install |
| simulator install + launch | PASS — `com.example.haeda: 7968` | iPhone, 메인 화면 정상 로드 |
| 백엔드 healthy | `Up 32 minutes (healthy)` | `docker compose ps backend` |
| 상점 화면 진입 (자동 탭) | PASS — 캡모자/비니/머리띠/페도라 카드 렌더 정상 | `/tmp/shop-list.png` |

### Verification (partial)

- 시각 e2e 의 "구매 직후 상단바 젬 숫자 감소" 순간 캡처: SKIPPED — 현재 잔액 20 으로 구매 가능한 30+ 아이템이 없어 직접 재현 불가. 단위 테스트가 Riverpod invalidate 동작을 1:1 검증하므로 동등한 신뢰도. 사용자가 잔액 충분한 계정에서 직접 구매 시 즉시 차감 확인 권장.

## Follow-ups

- (스코프 외) 코인/젬 용어 혼재 정리 — 백엔드 `gem_service` / `GemTransaction` 과 프론트 `coinBalanceProvider` / `coinTransactionsProvider` 가 같은 currency 를 다른 이름으로 부른다. 추후 별도 작업으로 통일 권장.
- (스코프 외) `coinBalanceProvider` 가 visible UI 에서 watch 되지 않는다 — `room_decorator_screen.dart` 에서만 사용. 잔액 표시는 `userStatsProvider` 가 단일 소스가 되도록 정리 가능.
- (pre-existing) `app/test/features/status_bar/widgets/status_bar_test.dart` 5개 실패 — SVG 아이콘 마이그레이션 후 "💎" emoji 검색이 더 이상 매치되지 않음. 별도 fix 필요.

## Related

- 수정 파일: `app/lib/features/character/providers/shop_provider.dart`
- 신규 테스트: `app/test/features/character/providers/shop_provider_test.dart`
- working 패턴 참조: `app/lib/features/challenge_space/screens/create_verification_screen.dart:234`
- 시뮬레이터 캡처: `docs/reports/screenshots/2026-04-25-feature-shop-money-deduct-01.png`

### Referenced Reports

- `docs/reports/2026-04-19-feature-room-decoration.md` — 미니룸 장식 슬라이스에서 `myItemsProvider` / `shopItemsProvider` 도입 맥락. 본 수정은 그 invalidate 목록에 `userStatsProvider` 1개를 추가만 함, 기존 동작 보존.
- `docs/reports/2026-04-20-feature-character-cyworld-style.md` — 캐릭터 32×32 시도 + 롤백 보고서. 본 수정과 무관 (provider 변경만, character_avatar / accessory 미수정).

— 검색 키워드: `shop`, `coin`, `상점`, `구매`, `코인`, `app/lib/features/character/providers`. 직접 관련 보고서는 없음.
