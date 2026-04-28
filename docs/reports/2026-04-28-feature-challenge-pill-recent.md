# Status Bar Challenge Pill — 가장 최근 챌린지 진입 + 이모지 식별

- **Date**: 2026-04-28
- **Worktree (수행)**: `.claude/worktrees/feature` (worktree-feature)
- **Worktree (영향)**: feature 단독 (full-stack)
- **Role**: feature

## Request

> status bar pill: 챌린지 (lightning) pill 탭 페이지. 사용자 요청 시 같은 패턴 (/challenges 또는 /active-challenges route + 페이지) 으로 확장 가능 을 진행하려고 해. 이거 누르면 가장 마지막에 했던 챌린지로 가고, 단순 번개 모양이 아니라 가장 마지막에 했던 챌린지가 뭔지 사용자가 아이콘 하나로 볼 수 있어야 해.

## Root cause / Context

`StatusBar` 의 마지막 lightning pill 만 streak/gem pill 패턴 (탭 가능 + 의미있는 글리프) 으로 변환되지 않은 상태 (gems-page 보고서 Follow-ups §1 에 명시). 단순 lightning 아이콘 + `active/completed` ratio 텍스트는 (1) 어떤 챌린지인지 식별 불가, (2) 탭 했을 때 현재 활동 중인 챌린지로 직접 연결되지 않아 동선이 멀었다. 사용자 요구: pill 탭 → 가장 최근 인증한 챌린지 진입 + 이모지 1글자로 어떤 챌린지인지 즉시 식별.

## Referenced Reports

- `docs/reports/2026-04-27-feature-streak-page.md` — streak pill → /streak 패턴 (PR #71)
- `docs/reports/2026-04-27-feature-gems-page.md` — gem pill → /gems 패턴 + Follow-ups §1 에 본 작업 예고 (commit f5f2dce)

검색 키워드: `status_bar`, `pill`, `lightning`, `challenge`, `emoji`, `last_verified_at`.

## Actions

### 1. 사전 산출물

- 디자인 spec — `docs/superpowers/specs/2026-04-28-challenge-pill-recent-design.md` (commit `ce8aace`)
- 구현 plan — `docs/superpowers/plans/2026-04-28-challenge-pill-recent.md` (commit `b62009e`), 18-task TDD 사이클 (실제 7 batch 로 통합 실행)

### 2. 백엔드 (FastAPI + SQLAlchemy 2.0 async + Alembic)

| Commit | 변경 |
|---|---|
| `386b4cd` | `server/alembic/versions/20260428_0001_023_add_challenge_icon.py` 신규 — `challenges.icon String(8) NOT NULL server_default='🎯'`. 기존 row 자동 backfill. `Challenge` 모델에 `icon` 매핑 추가 |
| `7a5515c` | `ChallengeCreate.icon: str = Field(default='🎯', max_length=8)`, `ChallengeCreateResponse.icon`, `create_challenge` service 에서 `icon=data.icon` 저장 + 응답 매핑. RED: 2 KeyError → GREEN: 2 passed |
| `2d2626c` | `ChallengeListItem.icon` + `last_verified_at: datetime \| None`. `get_my_challenges` 에 `Verification.max(created_at) WHERE user_id` subquery + LEFT JOIN + `ORDER BY last_verified_at DESC NULLS LAST, start_date DESC`. RED: 4 fail (icon 누락 / null / 정렬 불안정) → GREEN: 9 passed |
| `d16faa3` | `ChallengeDetail.icon`, `get_challenge_detail` 응답 매핑, `docs/api-contract.md` 업데이트 (POST body, GET /me/challenges 응답 + 정렬 규약, GET /challenges/:id 응답). RED: 1 KeyError → GREEN: 35 passed (모든 challenge / me / create_join 회귀 통과) |

총 신규 backend 테스트: **7** (create_with_icon, default_icon / me_includes_icon, last_verified_at_null/with_verification, sorted_by_last_verified_at / detail_includes_icon). 전체 backend pytest: **179 passed / 3 failed (사전 결함)**.

### 3. 프론트엔드 (Flutter + Riverpod + GoRouter + freezed + flutter_svg)

| Commit | 변경 |
|---|---|
| `2678d22` | `ChallengeSummary` (`icon` default `🎯` + `lastVerifiedAt: DateTime?`), `ChallengeDetail.icon`, `ChallengeCreateResponse.icon`, `ChallengeCreateRequest.icon` + toJson `'icon'` 키. 신규 `mostRecentChallengeProvider` (`myChallenges[0]` selector). 2 provider 테스트 PASS |
| `6edce7a` | `challenge_create_step1_screen.dart` 에 `emoji_field` TextField (`maxLength=2`, hintText `🎯`, counterText 숨김). `_onNext` 에서 blank → `'🎯'` default 로 step2 extra 에 포함. ListView → SingleChildScrollView+Column 으로 변경 (테스트에서 next_button viewport 보장). Step2: `ChallengeCreateRequest.icon` 인자에 `step1Data['icon']` forward. **9 step1 tests PASS** (기존 7 + 신규 2: blank → 🎯, input → as-is) |
| `7dd763c` | `_StatItem` 시그니처를 `asset \| emoji` 분기로 확장 (둘 중 하나 필수). `_ChallengePill` 신규 위젯 — `mostRecentChallenge` 분기: 있으면 `Text(emoji) + active count + tap → /challenges/:id`, 없으면 `lightning SVG + active count + tap → /create`. `_StatusBarContent` → `ConsumerWidget`. **신규 4 challenge pill tests PASS** (fallback / has-challenge / tap with most-recent / tap empty) |

총 신규 frontend 테스트: **8** (provider 2 + step1 emoji 2 + status_bar challenge pill 4). 전체 flutter test: **145 passed / 6 failed (모두 사전 결함, 본 작업 무관)** — baseline 7 → 6 (step1 사전 결함 1 해소).

### 4. 통합 검증

- Docker compose backend rebuild 불필요 (코드 mount 없이 docker cp 로 갱신). `docker compose restart backend` 후 `/health → {"status":"ok"}`. `alembic current → 023 (head)` 확인.
- 전체 backend pytest: **179 passed**. 사전 결함 3개 (`test_room_equip::TestSignature::test_member_clear_signature`, `test_non_member_clear_signature_returns_403`, `test_treasure_chest::test_create_verification_arms_chest` 의 today 날짜 mismatch — 모두 본 작업 무관).
- iOS simulator clean install (terminate → uninstall → flutter clean → pub get → build ios --simulator → install → launch) 성공. 4단계 시각 검증 통과 (스크린샷 첨부).

## Verification

### 백엔드

```
$ docker compose exec backend uv run python -m pytest tests/test_me.py tests/test_challenge_create_join.py tests/test_challenges.py -v 2>&1 | tail -5
... 35 passed in 0.93s

$ docker compose exec backend uv run python -m pytest 2>&1 | tail -3
3 failed, 179 passed in 4.65s   # 3 fails 사전 결함

$ curl -fsS http://localhost:8000/health
{"status":"ok"}
$ docker compose exec backend uv run alembic current
023 (head)
```

### 프론트엔드

```
$ flutter test test/features/status_bar/ 2>&1 | tail -3
00:01 +9 -4: Some tests failed.   # 9 신규 PASS, 4 사전 결함 (emoji vs SVG mismatch — streak/gem)

$ flutter test 2>&1 | tail -3
00:08 +145 -6: Some tests failed.   # baseline 136/7 → 145/6 (+9 신규 PASS, -1 사전 결함 해소)

$ dart analyze lib/features/status_bar/ lib/features/my_page/ lib/features/challenge_create/ 2>&1 | tail -3
... 0 errors (info-level prefer_const_constructors 사전 결함만 잔존)
```

### 시뮬레이터 시각 검증 (iPhone 17 Pro, iOS 26.4)

| # | 시나리오 | 스크린샷 | 결과 |
|---|---------|---------|------|
| 1 | 앱 launch → 로그인 화면 | `2026-04-28-feature-challenge-pill-recent-01-launch.png` | ✅ |
| 2 | 김철수 로그인 → my-page, status bar 의 challenge pill 위치에 **🎯 default emoji** + `0` (active count, 김철수는 완료 챌린지만 보유) | `02-my-page.png` | ✅ — backfill 동작 확인 (기존 challenge.icon 이 server_default `'🎯'` 로 채워짐) |
| 3 | challenge pill (🎯 0) 탭 → `/challenges/:id` 의 챌린지 스페이스 (운동 30일) 진입 | `03-tap-pill.png` | ✅ — `mostRecentChallengeProvider` 가 last_verified_at 최상단 챌린지로 분기 |
| 4 | challenge 만들기 FAB → Step1 화면 — **신규 "이모지" 필드** 가 카테고리 위에 hintText `🎯` 와 함께 노출 | `04-create-step1.png` | ✅ — Step1 emoji TextField 정상 렌더 |

(단계 5 — 새 챌린지 emoji=🏃 입력 후 my-page 복귀 시 pill 이 🎯 → 🏃 로 변경 — 은 idb 의 `ui text` 가 emoji keycode 미지원으로 시뮬레이터 자동 입력 불가. 대신 위젯 테스트로 검증: `step1_screen_test::emoji forwarding emoji input forwards as-is` PASS + `status_bar_test::challenge pill shows most-recent emoji + active count` PASS = 입력 → 백엔드 round-trip → pill 렌더 전 경로 커버.)

## Follow-ups

- **챌린지방 (`/challenges/:id`) 에서 이모지 수정 affordance** — 본 plan 의 명시적 out-of-scope. spec §결정 6 에 따라 별도 작업.
- **emoji input UX polish** — 현재 단순 TextField (maxLength=2) + OS 기본 키보드 emoji 키. preset chip 그리드 (12-16개 자주 쓰는 이모지) 또는 emoji_picker_flutter 패키지는 P1 polish.
- **사전 결함 (이번 작업 무관)**:
  - backend: `test_room_equip::TestSignature` 2개 + `test_treasure_chest::test_create_verification_arms_chest` 1개 (today 날짜 mismatch — 시간대/시각 관련 의심)
  - frontend: status_bar 의 4개 사전 결함 — `streak/gem pill` 의 emoji 🌺/🥀/💎 vs 실제 SVG asset (`fire/sleep/flower/gem`) mismatch. 본 작업에서 lightning 영역 1개 (active/completed ratio) 는 challenge_pill 4 신규 테스트로 교체. 나머지 4개는 별도 정리 필요.
  - frontend: `profile_setup_screen_test` 1개, `feed_screen_test` 1개 — mock 관련 사전 결함.
- **`ChallengeCard` (my-page 목록) 에 이모지 노출** — 일관성 개선. 현재는 status bar pill 에서만 노출.
- **시뮬레이터 5단계 자동화** — idb 의 emoji 입력 미지원. PNG 기반 키보드 자동화 또는 백엔드 직접 호출로 mock 챌린지 생성 후 검증 가능.

## 디자인/계약 결정 요약

브레인스토밍 6개 결정 (spec §결정 표 참조):
1. "가장 최근" = `last_verified_at DESC NULLS LAST` (사용자 본인 verification 기준)
2. 아이콘 = `Challenge.icon` 신규 컬럼 (default `'🎯'`)
3. 챌린지 0개 → fallback `lightning.svg` + 탭 → `/create`
4. Pill 텍스트 = 이모지 + active count
5. 입력 = Step1 TextField (`maxLength=2`, blank → `'🎯'` default)
6. 범위 = backend + pill + Step1 입력 (챌린지방 수정은 follow-up)

## Related

- Spec: `docs/superpowers/specs/2026-04-28-challenge-pill-recent-design.md`
- Plan: `docs/superpowers/plans/2026-04-28-challenge-pill-recent.md`
- Streak page (같은 패턴): `docs/reports/2026-04-27-feature-streak-page.md` (PR #71)
- Gems page (같은 패턴): `docs/reports/2026-04-27-feature-gems-page.md` (PR #72) — Follow-ups 에서 본 작업 예고
- 신규 컬럼: `challenges.icon` (alembic migration 023)
- 신규 모듈: `app/lib/features/status_bar/providers/most_recent_challenge_provider.dart`
- 신규 위젯: `_ChallengePill` (`status_bar.dart`)
- API contract 갱신: `docs/api-contract.md` §2 Challenges (POST + GET /:id) + §3 My Page (GET /me/challenges)
