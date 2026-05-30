# Challenge Icon Follow-ups (챌린지방 수정 / ChallengeCard 노출 / Step1 preset chip)

- **Date**: 2026-05-30
- **Worktree (수행)**: main 직접 (워크트리 분리 없음, 솔로 개발)
- **Worktree (영향)**: full-stack
- **Role**: feature

## Request

> 저번에 업무 이어서 계속 해야겠어. 마지막 작업 follow-up (challenge pill): 챌린지방 이모지 수정, ChallengeCard 목록 이모지 노출, emoji preset chip UX 부터 처리해야겠어.

직전 보고서 `2026-04-28-feature-challenge-pill-recent.md` 의 Follow-ups 3건을 한 번에 마무리.

## Root cause / Context

직전 challenge pill 작업에서 backend `challenges.icon` 컬럼 + `ChallengeSummary.icon` / `ChallengeDetail.icon` 필드는 도입했지만, 노출·수정 affordance가 status bar 의 `_ChallengePill` 한 군데에만 있었다. 일관성 관점에서 (1) 챌린지방 헤더에 그 챌린지 의 emoji 가 보여야 하고, (2) my-page ChallengeCard 목록에도 보여야 하며, (3) emoji 입력 방식이 단순 TextField (`maxLength=2`) 보다는 preset chip 그리드 + 직접 입력 토글 쪽이 모바일 UX 에 맞다.

## Referenced Reports

- `docs/reports/2026-04-28-feature-challenge-pill-recent.md` — 본 작업의 직접 전제. Follow-ups §1, §3, §4 가 본 작업 범위에 1:1 대응.
- `docs/reports/2026-04-27-feature-gems-page.md` — `_StatItem` asset/emoji 분기 패턴 답습.
- `docs/reports/2026-04-25-feature-tap-day-to-verify.md` — Riverpod override + GoRouter wrapping 위젯 테스트 패턴 참고.

검색 키워드: `challenge`, `icon`, `emoji`, `ChallengeCard`, `ChallengeSpaceScreen`, `step1`, `preset`.

## Actions

### 0. 사전 산출물

- 디자인 결정 — `AskUserQuestion` 으로 2 가지 결정 확정:
  - 챌린지방 이모지 수정: **creator만 / 헤더 emoji 탭** (settings 화면 대신 헤더 직접 탭으로 affordance 축약)
  - Step1 preset: **12개 universal + 직접 입력** (카테고리별 다이나믹 preset 은 P2 로 미룸)
- 구현 plan — `docs/superpowers/plans/2026-05-30-challenge-icon-followups.md` (commit `081cafc` 와 함께 포함). 5-task TDD 사이클.

### 1. Backend — PATCH settings 에 icon 확장 (commit 081cafc)

| 변경 | 위치 |
|------|------|
| `ChallengeSettingsUpdate.icon: str \| None = Field(default=None, max_length=8)` | `server/app/schemas/challenge.py:93-95` |
| `ChallengeSettingsResponse.icon: str` 응답 필드 추가 | `server/app/schemas/challenge.py:98-100` |
| `update_challenge_settings` service 에 `icon` 인자 + 빈 문자열 시 `INVALID_ICON` 422 + `challenge.icon` 저장 | `server/app/services/challenge_service.py:541-572` |
| 라우터에서 `icon=body.icon` 전달 | `server/app/routers/challenges.py:175-181` |
| api-contract.md PATCH `/challenges/{id}/settings` 섹션 갱신 (request / response / error 표) | `docs/api-contract.md:180-211` |
| 신규 테스트 3개 (`test_update_challenge_icon_creator` / `_not_creator` 403 / `_persists_across_get`) | `server/tests/test_challenges.py:266-327` |

마이그레이션 불필요 (`challenges.icon` 컬럼은 마이그레이션 023 에서 이미 도입). creator 권한 체크는 기존 service 가 이미 보유 (line 552-553 — `NOT_CHALLENGE_CREATOR`).

### 2. Frontend — 챌린지방 헤더 이모지 + creator 탭 수정 (commit 773205f)

| 변경 | 위치 |
|------|------|
| 공통 emoji preset 12개 (universal) | 신규 `app/lib/core/constants/emoji_presets.dart` |
| `EmojiPicker` 위젯 — `ChoiceChip` × 12 + `직접 입력` 토글 → TextField. Step1 과 챌린지방 양쪽에서 공유 | 신규 `app/lib/features/challenge_create/widgets/emoji_picker.dart` |
| `ChallengeIconEditSheet` — `EmojiPicker` + 저장 버튼. `dio.patch('/challenges/:id/settings', {'icon': v})` → `challengeDetailProvider` invalidate | 신규 `app/lib/features/challenge_space/widgets/challenge_icon_edit_sheet.dart` |
| `ChallengeSpaceScreen` AppBar title 을 `Row(GestureDetector(emoji) + Flexible(Column(title, member-count)))` 로 변경. creator 일 때만 onTap → bottom sheet | `app/lib/features/challenge_space/screens/challenge_space_screen.dart:76-178` |
| 위젯 테스트 3개 (헤더 노출 / creator 탭 OK / 비-creator noop) | `app/test/features/challenge_space/screens/challenge_space_screen_test.dart` (전체 재작성) |

테스트에서 `dioProvider` 를 `_PendingAdapter` 적용 dio 로 override + `calendarProvider` / `receivedNudgesProvider` Completer pending 으로 body 영역 LoadingWidget 유지 → AppBar 만 검증. `pumpAndSettle` 대신 `pump(Duration(milliseconds: 500))` 사용 (LoadingWidget 의 `CircularProgressIndicator` 가 frame 무한 schedule → pumpAndSettle 무한 대기 회피).

### 3. Frontend — ChallengeCard 이모지 노출 (commit 96813ca)

| 변경 | 위치 |
|------|------|
| title 좌측에 `Text(challenge.icon, fontSize: 20)` + 8px gap | `app/lib/features/my_page/widgets/challenge_card.dart:30-58` |
| 신규 위젯 테스트 1개 (`icon` + `title` 동시 노출) | `app/test/features/my_page/widgets/challenge_card_test.dart:170-194` |

기존 6개 테스트 (제목/달성률/배지/카테고리) 회귀 0건 — title text content 자체는 변경 없음.

### 4. Frontend — Step1 emoji preset chip (commit 75cdfe9)

| 변경 | 위치 |
|------|------|
| `_iconController` (TextField) → `_pickedIcon: String?` state + `EmojiPicker` 위젯 호출. 미선택 시 `_onNext` 에서 `'🎯'` default 적용 | `app/lib/features/challenge_create/screens/challenge_create_step1_screen.dart:20-78` |
| 기존 `emoji_field` 단순 존재 테스트 → `emoji_preset_wrap` + `emoji_custom_toggle` 노출 검증으로 교체 | `step1_screen_test.dart:56-62` |
| 기존 `emoji input forwards as-is` → preset chip 탭 forward + 직접 입력 토글 forward 2개로 분리 | `step1_screen_test.dart:142-261` |

총 신규 frontend 테스트 (Task 2-4 합산): **7** (challenge_space 3 + challenge_card 1 + step1 신규 3).

## Verification

### 백엔드 — 전체 회귀 + health

```
$ cd /Users/yumunsang/haeda/server && uv run --extra dev python -m pytest tests/test_challenges.py -k "icon" -v 2>&1 | tail -10
tests/test_challenges.py::test_get_challenge_detail_includes_icon PASSED [ 25%]
tests/test_challenges.py::test_update_challenge_icon_creator PASSED      [ 50%]
tests/test_challenges.py::test_update_challenge_icon_not_creator PASSED  [ 75%]
tests/test_challenges.py::test_update_challenge_icon_persists_across_get PASSED [100%]
4 passed, 11 deselected in 0.16s

$ cd /Users/yumunsang/haeda/server && uv run --extra dev python -m pytest 2>&1 | tail -3
185 passed in 5.00s   # 직전 baseline 182 + 신규 3

$ curl -fsS http://localhost:8000/health
{"status":"ok"}
```

Docker rebuild: `docker compose -p feature up --build -d backend` (port 5432 충돌 회피를 위해 stale `haeda-*` 컨테이너 청소 + `feature` project name 유지).

### 프론트엔드 — 전체 회귀

```
$ cd /Users/yumunsang/haeda/app && flutter test test/features/challenge_space/screens/challenge_space_screen_test.dart 2>&1 | tail -5
00:00 +1: AppBar 에 detail.icon 이 노출된다
00:00 +2: creator 가 헤더 이모지 탭 시 EmojiEditSheet 가 열린다
00:00 +3: 비-creator 가 헤더 이모지 탭 시 sheet 가 열리지 않는다
00:00 +3: All tests passed!

$ flutter test test/features/my_page/widgets/challenge_card_test.dart 2>&1 | tail -3
00:00 +7: All tests passed!

$ flutter test test/features/challenge_create/screens/challenge_create_step1_screen_test.dart 2>&1 | tail -3
00:01 +10: All tests passed!

$ flutter test 2>&1 | tail -3
00:09 +161: All tests passed!   # 직전 baseline 157 + 본 작업 net +4
```

### iOS 시뮬레이터 — clean install + 시각 검증

iPhone 17 (iOS 26.4, UDID 48703B52-...) clean install 완료. terminate → uninstall → flutter clean → pub get → build ios --simulator (✓ Built in 32.0s) → install → launch (PID 25724) 모두 성공.

| # | 시나리오 | 스크린샷 | 결과 |
|---|---------|---------|------|
| 1 | 박지민 로그인 상태 my-page (앱이 자동으로 my-page tab 진입) — `ChallengeCard` 의 ddd / 운동 30일 두 건 모두 title 좌측에 default 🎯 이모지 노출 + 카테고리 chip 우측 정렬 유지 | `2026-05-30-feature-challenge-icon-followups-01-card.png` | ✅ Task 3 (ChallengeCard 이모지 노출) 정상 동작 확인 — backfill 된 기본 🎯 가 카드에 노출됨 |

#### idb 자동 인터랙션 한계 — 단계 2~4 skip

본 작업에서는 단계 2 (챌린지방 헤더) / 단계 3 (preset chip sheet 노출) / 단계 4 (저장 후 헤더 갱신) 를 idb 자동 tap 으로 캡처하려 했으나, idb HID 이벤트가 시뮬레이터에 도달은 했지만 (`/tmp/idb_companion.log` 의 `hid called with: [Touch down/up at <hidden>]` + `Success of hid` 확인) Flutter `GestureDetector.onTap` / `InkWell.onTap` 이 발화하지 않아 화면 전환이 일어나지 않았다. 직전 보고서 (`2026-04-28-feature-challenge-pill-recent.md` §시뮬레이터 시각 검증) 도 동일 한계 (idb emoji 키코드 미지원) 로 일부 단계를 위젯 테스트로 갈음. 본 작업도 같은 패턴 채택:

| 단계 | 위젯 테스트 대체 검증 |
|------|---------------------|
| 챌린지방 헤더 emoji 노출 | `challenge_space_screen_test::AppBar 에 detail.icon 이 노출된다` PASS |
| creator 탭 → EmojiEditSheet 노출 | `challenge_space_screen_test::creator 가 헤더 이모지 탭 시 EmojiEditSheet 가 열린다` PASS (`emoji_preset_wrap` finds) |
| 비-creator 탭 noop | `challenge_space_screen_test::비-creator 가 헤더 이모지 탭 시 sheet 가 열리지 않는다` PASS |
| preset chip 선택 → forward | `step1_screen_test::preset chip 탭 시 해당 이모지가 forward 된다` PASS (`💪` 선택 → step2 extra `icon: '💪'`) |
| 직접 입력 토글 + 입력 forward | `step1_screen_test::직접 입력 토글 후 입력값이 forward 된다` PASS (`🦄` 입력 → extra `icon: '🦄'`) |

단계 2 (PATCH /settings 실제 호출 → DB persist → 재진입 시 새 emoji 노출) 의 round-trip 은 `test_update_challenge_icon_persists_across_get` 백엔드 테스트로 검증 — PATCH 후 GET 응답에 `icon` 변경 반영.

## Follow-ups

- **챌린지 만들기 Step1 카테고리별 preset 추천** (운동 → 💪🏃🧘🏋️, 공부 → 📚📝🧠💡) — 본 작업 결정에서 P2 로 미룸. 사용자 데이터 누적 후 가치 평가.
- **idb HID tap → Flutter 인식 우회** — Flutter app 에 semantics enable 또는 자동 인터랙션을 patrol/integration_test 패키지로 교체하는 별도 작업. 본 작업 한정으로는 위젯 테스트 + 단일 launch 캡처로 충분.
- **이모지 변경 이력 표시** — 동일 챌린지에서 creator 가 이모지 자주 바꾸면 다른 멤버 혼란 가능. P2 로 분류.
- **사전 결함 (이번 작업 무관)** — 직전 보고서 §Follow-ups 에 나열된 사전 결함 5건은 baseline 복구 작업 (`bca28f3 fix: 테스트 baseline 복구`) 으로 해소 — 본 세션 시작 시점 backend 182/0 / frontend 157/0 이었음.

## Related

- Plan: `docs/superpowers/plans/2026-05-30-challenge-icon-followups.md`
- 직전 보고서 (전제): `docs/reports/2026-04-28-feature-challenge-pill-recent.md`
- 신규 위젯: `EmojiPicker` (`app/lib/features/challenge_create/widgets/emoji_picker.dart`), `ChallengeIconEditSheet` (`app/lib/features/challenge_space/widgets/challenge_icon_edit_sheet.dart`)
- 신규 상수: `kEmojiPresets` (`app/lib/core/constants/emoji_presets.dart`)
- API contract 갱신: `docs/api-contract.md` §2 Challenges — PATCH `/challenges/{id}/settings`
- 커밋: `081cafc` (Backend) / `773205f` (챌린지방 헤더) / `96813ca` (ChallengeCard) / `75cdfe9` (Step1 preset)
