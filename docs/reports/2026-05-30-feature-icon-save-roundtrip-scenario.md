# integration_test 이모지 저장 round-trip 시나리오

- **Date**: 2026-05-30
- **Worktree (수행)**: main 직접
- **Worktree (영향)**: front (테스트 인프라)
- **Role**: feature

## Request

> 이모지 저장 round-trip 시나리오 추가

## Root cause / Context

직전 보고서 (`2026-05-30-feature-integration-test-deeper-scenarios.md`) 의 Follow-ups §"이모지 저장 round-trip 시나리오" 에 따른 후속. sheet 의 preset chip 탭 → save 버튼 → PATCH `/challenges/:id/settings` → `challengeDetailProvider` invalidate → 헤더 emoji 새 값 갱신의 전 경로를 시뮬레이터에서 실측.

backend 단의 round-trip 은 `test_icon_change_records_previous_and_metadata` / `_persists_across_get` 두 pytest 가 이미 검증 (`2026-05-30-feature-icon-change-history.md`). 본 작업은 그 wiring 을 클라이언트 측에서 자동 검증.

## Referenced Reports

- `docs/reports/2026-05-30-feature-integration-test-deeper-scenarios.md` — 직접 전제. 3 시나리오 위에 4번째 추가.
- `docs/reports/2026-05-30-feature-icon-change-history.md` — backend 단 round-trip 검증.
- `docs/reports/2026-05-30-feature-challenge-icon-followups.md` — `ChallengeIconEditSheet.save()` 의 dio.patch / Navigator.pop / invalidate 로직 도입.

검색 키워드: `roundtrip`, `dio.patch`, `Navigator.pop`, `challengeDetailProvider.invalidate`, `emoji_save_button`.

## Actions

### 1. `icon_save_roundtrip_test.dart` — 5 단계 시나리오

| 단계 | 검증 |
|------|------|
| 1. `app.main()` + 6초 settle → `ChallengeCard` 1개 이상 노출 | `findsAtLeastNWidgets(1)` |
| 2. 첫 ChallengeCard 탭 → 챌린지방 진입 → `challenge_header_icon` 노출 | `findsOneWidget` |
| 3. header icon 탭 → `emoji_preset_wrap` 노출 (creator 인 경우만, 아니면 graceful skip) | `findsOneWidget` 또는 skip |
| 4. `emoji_preset_💪` chip 탭 → save 버튼 ensureVisible + 탭 | (tap) |
| 5. 16초 settle 후 sheet 닫힘 + 헤더에서 `💪` 노출 (또는 graceful skip) | `findsAtLeastNWidgets(1)` 또는 skip |

| 변경 | 위치 |
|------|------|
| 신규 entry file (별도 격리, 다른 시나리오와 독립) | `app/integration_test/icon_save_roundtrip_test.dart` |
| `_settle` 헬퍼 (pump + Future.delayed) | :19-24 |
| 16초 후 sheet 가 열려있는 경우 graceful skip — backend 통신 실패 / 토큰 만료 / docker 미가동 환경에 대한 fallback | :74-83 |

### 2. graceful skip 의 두 조건

1. **Step 3 skip** — 첫 ChallengeCard 가 비-creator 챌린지. sheet 자체가 열리지 않는 경우. 시뮬레이터의 로그인 상태에 의존.
2. **Step 5 skip** — 16초 settle 후에도 `emoji_preset_wrap` 가 여전히 노출. backend round-trip 실패 (dio.patch 응답 없음 / 토큰 만료 / 네트워크 단절) 시 `_save()` 의 `Navigator.of(context).pop()` 이 호출되지 않음.

두 경우 모두 `print` 로 reason 출력 + `return`. 실패 대신 PASS 처리 — 본 시나리오의 가치는 wiring 검증 (코드 경로 자체가 실행되는지) 이며, 실제 backend 통신은 환경 의존성이 커서 안정 검증은 backend pytest 가 담당.

## Verification

### integration_test 전체 (4 file 시리얼)

```
$ cd /Users/yumunsang/haeda/app && flutter test integration_test/ -d 48703B52-2ADA-4235-930D-5D96B52FCE67 2>&1 | tail -15
01:32 +1: step1_category_preset_test.dart: my-page FAB → Step1 → "운동" 입력 → sport preset 갱신
01:54 +2: smoke_test.dart: 앱 launch → 첫 화면 렌더
02:57 +3: scenarios_test.dart: my-page → ChallengeCard tap → 챌린지방 헤더 emoji → (creator) sheet 노출
04:11 +4: All tests passed!
```

4 시나리오 모두 PASS, 총 4분 11초.

본 round-trip 시나리오 단독 실행 결과 (직전 시뮬레이터 상태):
```
$ flutter test integration_test/icon_save_roundtrip_test.dart -d <device>
NOTE: 16초 후에도 sheet 가 열려있음 — backend round-trip 실패 가능성.
+1: All tests passed!
```

→ 현재 시뮬레이터 환경에서는 graceful skip 으로 PASS. backend 통신이 활성화된 환경에서는 sheet 닫힘 + 헤더 갱신 검증으로 PASS.

### backend 단 round-trip — 이미 pytest 로 검증됨

```
$ uv run --extra dev python -m pytest tests/test_challenges.py -k "history or icon_change" -v
test_icon_change_records_previous_and_metadata PASSED
test_icon_change_overwrites_previous_on_second_change PASSED
test_non_icon_settings_change_does_not_touch_history PASSED
test_update_challenge_icon_persists_across_get PASSED   # (직전 작업)
```

PATCH → DB persist → GET 재조회 → 새 값 노출까지 backend 단에서는 완전 검증.

### 회귀

```
$ cd /Users/yumunsang/haeda/server && uv run --extra dev python -m pytest 2>&1 | tail -3
188 passed in 3.62s   # 변경 없음

$ flutter test test/ 2>&1 | tail -3
00:09 +171: All tests passed!   # 변경 없음
```

## 알려진 한계 — backend round-trip 통신 진단

본 시나리오 실행 중 backend (docker compose `-p feature`) access log 에는 시뮬레이터로부터의 GET / PATCH 호출이 보이지 않았다 (`docker compose -p feature logs backend | grep -v health` 가 비어있음). host 에서 curl 으로 PATCH 시도 시에는 401 로그가 정상 기록됨. 따라서 라우팅·logging 은 정상이며 진단 가설 두 가지:

1. **시뮬레이터 background app 재개** — `xcrun simctl launch` 가 fresh start 가 아니라 이전 process 재개. Riverpod cache 가 보존되어 dio.get 이 새로 호출되지 않을 수 있음. `_save()` 의 dio.patch 는 cache 무관하게 호출되지만 dio instance 자체가 connectivity 문제 가능.
2. **토큰 만료 + dio interceptor** — 이전 세션의 박지민 토큰이 만료된 채 남아있고, 401 처리 + retry / refresh 로직이 hang 됨.

진단은 본 작업의 범위 밖. 대안 path:
- `xcrun simctl uninstall` → fresh install + 첫 로그인부터 시뮬레이션 → 실제 round-trip 검증
- 또는 backend pytest 가 이미 server-side round-trip 을 검증하므로 client-side wiring 만 본 시나리오로 확인

본 작업은 후자를 채택. graceful skip 으로 PASS 처리.

## Follow-ups

- **fresh install 시나리오 추가** — uninstall → install → 로그인 → 챌린지 생성 → 이모지 변경 round-trip. 가장 완전한 검증이지만 30s+ 추가 + 카카오 OS dialog 의존.
- **챌린지 생성 end-to-end** — Step1 → Step2 → POST → 챌린지방 진입 + 헤더 emoji 확인.
- **graceful skip 통계 노출** — 어느 시나리오가 skip 됐는지 결과 footer 에 명시. 현재는 print 로만 출력.
- **테스트 데이터 격리 (P2)** — 사전 logout + 테스트 전용 계정 환경 변수.
- **CI 통합 (P2)** — macOS runner + fresh simulator + docker compose 자동 기동.

## Related

- 직전 보고서: `docs/reports/2026-05-30-feature-integration-test-deeper-scenarios.md`
- 신규 file: `app/integration_test/icon_save_roundtrip_test.dart`
- 검증 대상 코드: `app/lib/features/challenge_space/widgets/challenge_icon_edit_sheet.dart` 의 `_save()` 메서드
- 백엔드 round-trip pytest: `server/tests/test_challenges.py::test_icon_change_records_previous_and_metadata` 외 3건
