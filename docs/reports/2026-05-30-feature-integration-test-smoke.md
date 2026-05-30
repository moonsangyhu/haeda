# integration_test 도입 (patrol → integration_test 전환)

- **Date**: 2026-05-30
- **Worktree (수행)**: main 직접
- **Worktree (영향)**: front (테스트 인프라)
- **Role**: feature

## Request

> 3. patrol 도입 → patrol_cli 4.4 절대 경로 버그 발견 → **patrol 제거 + integration_test 만 사용 (추천)** 으로 방향 전환

## Root cause / Context

지난 세 개 보고서 (`2026-05-30-feature-challenge-icon-followups` / `category-aware-presets` / `icon-change-history`) 가 공통적으로 "idb HID → Flutter `GestureDetector.onTap` 미인식" 한계로 시뮬레이터 자동 인터랙션 검증을 위젯 테스트로 갈음했다. 이를 우회할 수 있는 표준 방법은 Flutter 의 `integration_test` 패키지 — widget tester 가 framework 레벨에서 `tap` 을 발화시키므로 native HID 우회.

처음에는 patrol (native automation superset) 을 도입하려 했으나, **patrol_cli 4.4.0 의 절대 경로 버그** (`patrol_test/test_bundle.dart` 에서 `import 'Users/yumunsang/...'` 로 leading `/` 가 strip 됨) 로 build 실패. 다운그레이드 / 패치 / 분석 대신 **Flutter 공식 `integration_test` 만 사용** 으로 전환했다 — MVP 범위에서는 native automation (permission dialog 등) 이 불필요.

## Referenced Reports

- `docs/reports/2026-05-30-feature-challenge-icon-followups.md` Follow-ups §"patrol/integration_test 도입"
- `docs/reports/2026-05-30-feature-category-aware-presets.md` Follow-ups §"patrol/integration_test 도입"
- `docs/reports/2026-05-30-feature-icon-change-history.md` Follow-ups §"patrol/integration_test 도입"
- `docs/reports/2026-04-25-feature-install-idb-auto-tap.md` — idb 도구 도입 (HID tap 한계의 원인 기록)

검색 키워드: `patrol`, `integration_test`, `idb`, `GestureDetector`, `IntegrationTestWidgetsFlutterBinding`.

## Actions

### 1. patrol 시도 → 4.4 경로 버그 확인 → 제거

| 단계 | 결과 |
|------|------|
| `dart pub global activate patrol_cli` | 4.4.0 설치 OK |
| `flutter pub add dev:patrol dev:integration_test:{"sdk":"flutter"}` | patrol 4.6.1 + integration_test SDK 추가 |
| `patrol test --target integration_test/smoke_test.dart -d "iPhone 17"` | `xcodebuild exited 65` |
| 원인 분석 | `patrol_test/test_bundle.dart` 의 `import 'Users/yumunsang/...'` — 절대 경로의 leading `/` 가 strip 되어 잘못된 상대 경로로 변환 (patrol_cli 4.4 의 알려진 버그) |
| `flutter pub remove patrol` + `rm -rf patrol_test/` | patrol_finders / patrol_log / patrol 패키지 5건 제거 |
| `pubspec.yaml` 정리 후 | `integration_test: sdk: flutter` 만 dev-dep 에 잔존 |

### 2. integration_test 스모크

| 변경 | 위치 |
|------|------|
| `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` + 단일 `testWidgets` — `app.main()` → real-time delay 10초 (1초 × 10회 pump + delayed) → `Scaffold` 1개 이상 렌더 검증 | `app/integration_test/smoke_test.dart` (신규) |
| `pumpAndSettle` 회피 — LoadingWidget / CircularProgressIndicator 가 frame 무한 schedule 하므로 timeout. `pump(duration)` + `Future.delayed(duration)` 조합으로 dio / 자동 로그인 future 진행 + frame 진행 | 같은 파일 :22-26 |
| 실행 명령: `flutter test integration_test/smoke_test.dart -d 48703B52-2ADA-4235-930D-5D96B52FCE67` | (스모크 명령 문서화) |

검증 자체는 weak (Scaffold 1개 이상) — 본 작업의 목적은 "integration_test 인프라가 시뮬레이터에서 정상 동작한다" 의 증명이며, 상세 화면 검증은 후속 시나리오에서 추가.

## Verification

### integration_test — 시뮬레이터 실측

```
$ cd /Users/yumunsang/haeda/app && flutter test integration_test/smoke_test.dart -d 48703B52-2ADA-4235-930D-5D96B52FCE67 2>&1 | tail -5
Xcode build done.                                           13.7s
00:00 +0: 앱 launch → 첫 화면 렌더
00:20 +1: (tearDownAll)
00:22 +1: All tests passed!
```

iPhone 17 (iOS 26.4) 에서 실제 launch + Scaffold 렌더 + tearDown 까지 22초 내 완료.

### 회귀 — backend + 기존 widget

```
$ flutter test test/ 2>&1 | tail -3
00:09 +171: All tests passed!   # 직전 171 유지

$ cd /Users/yumunsang/haeda/server && uv run --extra dev python -m pytest 2>&1 | tail -3
188 passed in 3.62s   # 직전 188 유지
```

회귀 0건.

## Follow-ups

- **deeper 시나리오 추가** — 로그인 화면 진입 / 로그인 완료 / my-page 접근 / ChallengeCard tap → 챌린지방 진입 시나리오. `tester.tap` 으로 GestureDetector 발화 가능 (idb HID 한계 우회).
- **테스트 데이터 격리** — 현재 smoke 는 simulator 의 기존 keychain (박지민 로그인 상태) 에 의존. 격리된 테스트 사용자 또는 사전 logout 단계 필요.
- **patrol_cli 재시도** — 4.5/4.6 또는 3.5 다운그레이드 시 native automation 사용 가능 (system dialog / permission). MVP 범위에는 P3.
- **CI 통합 (P2)** — 본 작업은 로컬 명령. GitHub Actions 의 macos runner 에서 simulator 시작 + flutter test 실행 가능하나 본 프로젝트는 솔로 + 로컬 검증 위주이므로 보류.

## Related

- 직전 보고서: `docs/reports/2026-05-30-feature-icon-change-history.md`
- 신규 파일: `app/integration_test/smoke_test.dart`
- 변경된 dev-dep: `app/pubspec.yaml` — `integration_test: sdk: flutter` 추가 (patrol 4.6.1 은 시도 후 제거)
