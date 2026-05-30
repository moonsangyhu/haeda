# integration_test 깊은 시나리오 추가 (챌린지방 진입 / sheet 열림 / Step1 preset 갱신)

- **Date**: 2026-05-30
- **Worktree (수행)**: main 직접
- **Worktree (영향)**: front (테스트 인프라)
- **Role**: feature

## Request

> 더 깊은 시나리오 추가해줘

## Root cause / Context

직전 보고서 (`2026-05-30-feature-integration-test-smoke.md`) 가 launch + Scaffold 렌더만 검증했다. 그 보고서 Follow-ups §"deeper 시나리오 추가" 에 명시된 대로, 직전 세 작업 (`challenge-icon-followups` / `category-aware-presets` / `icon-change-history`) 의 round-trip 을 시뮬레이터에서 실측 검증할 수 있도록 깊은 시나리오 추가.

핵심 가치: `tester.tap(find.byKey(...))` 가 framework 레벨 발화이므로 idb HID 가 GestureDetector 못 받는 한계가 사라진다. 위젯 테스트는 mocked dio 와 가짜 router 위에서, integration_test 는 실제 시뮬레이터 + 실제 dio + 실제 GoRouter 위에서 동작.

## Referenced Reports

- `docs/reports/2026-05-30-feature-integration-test-smoke.md` — 직접 전제. smoke 인프라 위에 시나리오 적층.
- `docs/reports/2026-05-30-feature-challenge-icon-followups.md` — 헤더 emoji + sheet 동작 위젯 테스트로만 갈음했던 부분.
- `docs/reports/2026-05-30-feature-category-aware-presets.md` — 카테고리 변경 → preset 갱신 위젯 테스트만 있던 부분.

검색 키워드: `integration_test`, `tester.tap`, `ChallengeCard`, `emoji_preset_wrap`, `category_field`, `floatingActionButton`.

## Actions

### 1. `scenarios_test.dart` — my-page → 챌린지방 진입 + 헤더 sheet

| 변경 | 위치 |
|------|------|
| 단일 `testWidgets` 안에 4 단계 시나리오 — ChallengeCard 존재 → tap → 챌린지방 header icon 노출 → header icon tap → EmojiPicker preset wrap 노출 | `app/integration_test/scenarios_test.dart` |
| 비-creator 챌린지일 경우 step 4 의 sheet 가 안 열리는 경우를 graceful skip 처리 (실패 대신 print + return) | 같은 파일 :55-68 |
| `_settle(tester, {seconds = 6})` 헬퍼 — `pump(1s)` + `Future.delayed(1s)` × n 으로 dio future / LoadingWidget 무한 frame 양쪽 처리 | :13-18 |

본 시나리오는 직전 작업의 헤더 emoji 노출 + creator sheet 동작을 시뮬레이터 실측으로 검증.

### 2. `step1_category_preset_test.dart` — Step1 카테고리별 preset 동적 갱신

| 변경 | 위치 |
|------|------|
| my-page FAB tap → Step1 진입 → universal preset 의 `🏋️` 미노출 확인 → category_field 에 '운동' 입력 → `🏋️` + `💪` chip 즉시 노출 | `app/integration_test/step1_category_preset_test.dart` (신규 별도 entry) |
| `_settle` 헬퍼 재정의 (별도 file 이므로) | :13-18 |

**별도 file 인 이유**: integration_test 는 file 단위로만 app state 격리 보장. 같은 file 내 다중 `testWidgets` 는 첫 시나리오의 GoRouter 위치가 잔존해 두 번째 시나리오의 `app.main()` 이 my-page 로 복귀시키지 못함 (실측 확인 — `FloatingActionButton` finds 0 으로 실패).

### 3. 한계와 graceful 처리

- 첫 ChallengeCard 가 비-creator 챌린지면 sheet 단계가 skip 된다 (헤더 icon tap 후 sheet 안 열림). 본 시나리오는 박지민이 직접 만든 챌린지가 첫 카드인 시뮬레이터 상태에 의존.
- LoadingWidget 의 `CircularProgressIndicator` 가 frame 무한 schedule 하므로 `pumpAndSettle` 사용 불가. `pump(duration)` + `Future.delayed` 조합으로 우회.
- `app.main()` 으로 startup 시 dio 자동 로그인 + provider 초기화 평균 6초 소요 → `_settle(seconds: 6)` 기본값.

## Verification

### integration_test — file 전체 시리얼 실행

```
$ cd /Users/yumunsang/haeda/app && flutter test integration_test/ -d 48703B52-2ADA-4235-930D-5D96B52FCE67 2>&1 | tail -15
00:00 +0: step1_category_preset_test.dart: my-page FAB → Step1 → 카테고리 "운동" 입력 → sport preset 갱신
00:20 +1: step1_category_preset_test.dart: (tearDownAll)
00:21 +1: loading smoke_test.dart
00:51 +1: smoke_test.dart: 앱 launch → 첫 화면 렌더
01:12 +2: smoke_test.dart: (tearDownAll)
01:13 +2: loading scenarios_test.dart
01:41 +2: scenarios_test.dart: my-page → ChallengeCard tap → 챌린지방 헤더 emoji → (creator 면) sheet 노출
02:07 +3: scenarios_test.dart: (tearDownAll)
02:08 +3: All tests passed!
```

3 files × 1 testWidgets 각각 = 총 3 시나리오 PASS, 2 분 8 초.

### 회귀 — backend + widget unchanged

```
$ cd /Users/yumunsang/haeda/server && uv run --extra dev python -m pytest 2>&1 | tail -3
188 passed in 3.62s   # 변경 없음

$ flutter test test/ 2>&1 | tail -3
00:09 +171: All tests passed!   # 변경 없음
```

## Follow-ups

- **이모지 저장 round-trip 시나리오** — sheet 의 preset chip tap → 저장 버튼 → PATCH 호출 → 헤더 emoji 갱신 확인. backend 실호출이라 환경 의존성 (현재 실행 중 docker compose backend) 필요.
- **챌린지 생성 end-to-end** — Step1 → Step2 → POST → 생성된 챌린지방 진입까지. 가장 큰 검증 단위.
- **테스트 데이터 격리** — 시뮬레이터 keychain 잔존 박지민에 의존. 사전 logout / 테스트 전용 계정으로 격리.
- **patrol_cli 3.5 재시도 + native dialog 처리** — kakao 로그인 OS dialog 자동화가 필요해질 경우.
- **CI 통합 (P2)** — 본 작업은 로컬 macOS + 부팅된 simulator 전제. GitHub Actions macos runner 또는 self-hosted.

## Related

- 직전 보고서: `docs/reports/2026-05-30-feature-integration-test-smoke.md`
- 신규 파일: `app/integration_test/scenarios_test.dart`, `app/integration_test/step1_category_preset_test.dart`
- 시각 검증 갈음 위젯 테스트: `app/test/features/challenge_space/screens/challenge_space_screen_test.dart` (3개), `app/test/features/challenge_create/screens/challenge_create_step1_screen_test.dart` (11개)
