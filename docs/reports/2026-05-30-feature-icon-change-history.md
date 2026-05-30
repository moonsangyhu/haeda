# 챌린지 이모지 변경 이력 (last-1 + 24h hint chip)

- **Date**: 2026-05-30
- **Worktree (수행)**: main 직접
- **Worktree (영향)**: full-stack
- **Role**: feature

## Request

> 2. 이모지 변경 이력 표시 — 이력 데이터 저장 방식: challenges 컬럼 3개 (last-1만 보존), 노출: 헤더 이모지 좌측 작은 hint chip.

## Root cause / Context

직전 작업으로 챌린지 이모지를 creator 가 자유롭게 변경 가능해졌지만, 그 변경이 다른 멤버에게 보이지 않아 "어제까지 🎯였던 게 갑자기 💪로?" 같은 컨텍스트 단절 발생 가능. last 1건만 보존 + 24h sliding window 로 챌린지방 진입 시 즉시 시각적 인지.

전체 audit log 테이블 (challenge_events) 도입은 over-engineering 으로 판단, P2 보류.

## Referenced Reports

- `docs/reports/2026-05-30-feature-challenge-icon-followups.md` — 본 작업 직접 전제. Follow-ups §"이모지 변경 이력 표시".
- `docs/reports/2026-05-30-feature-category-aware-presets.md` — 직전 polish 작업.
- `docs/reports/2026-04-28-feature-challenge-pill-recent.md` — `challenges.icon` 도입 (alembic 023).

검색 키워드: `previous_icon`, `icon_changed_at`, `icon_changed_by_user_id`, `hint chip`, `audit`.

## Actions

### 1. Backend — 마이그레이션 + history 기록 (commit 5430b90)

| 변경 | 위치 |
|------|------|
| alembic 024: `challenges` 에 `previous_icon String(8)` / `icon_changed_at TIMESTAMP(timezone=True)` / `icon_changed_by_user_id UUID FK users.id ON DELETE SET NULL` (모두 nullable) | `server/alembic/versions/20260530_0001_024_add_challenge_icon_history.py` |
| `Challenge` 모델 3 필드 매핑 | `server/app/models/challenge.py:49-58` |
| `ChallengeDetail` 응답 3 필드 추가 (모두 Optional, default None) | `server/app/schemas/challenge.py:71-91` |
| `update_challenge_settings` icon 분기에서 `stripped != challenge.icon` 일 때만 history 갱신 — 동일 값 재저장은 noop | `server/app/services/challenge_service.py:560-569` |
| `get_challenge_detail` 응답 매핑에 3 필드 포함 | `challenge_service.py:220-225` |
| `api-contract.md` GET /challenges/:id 섹션에 3 필드 + 의미 표 | `docs/api-contract.md:280-294` |
| 신규 테스트 3개 (`test_icon_change_records_previous_and_metadata` / `_overwrites_previous_on_second_change` / `test_non_icon_settings_change_does_not_touch_history`) | `server/tests/test_challenges.py:340-419` |

마이그레이션 head: **024**. SET NULL 정책으로 사용자 삭제 시 챌린지는 유지되고 변경자만 unknown.

### 2. Frontend — ChallengeDetail 확장 + 헤더 hint chip (commit 다음 step)

| 변경 | 위치 |
|------|------|
| `ChallengeDetail.previousIcon: String?` / `iconChangedAt: DateTime?` / `iconChangedByUserId: String?` freezed 필드 추가 + json 키 매핑 | `app/lib/features/challenge_space/models/challenge_detail.dart:38-41` |
| freezed 재생성 (build_runner 180 outputs) | (codegen) |
| 헤더 `Row` 안 emoji 좌측에 `_IconChangeHint(previousIcon)` 조건부 노출 — `previousIcon != null && iconChangedAt < 24h` 일 때 | `app/lib/features/challenge_space/screens/challenge_space_screen.dart:107-167` |
| `_IconChangeHint` widget — 작은 rounded 컨테이너 + `Icons.history` + previous emoji (opacity 0.7, surfaceContainerHighest 배경) | 같은 파일 끝 (new private widget) |
| 위젯 테스트 3개 (24h 이내 노출 / 24h 초과 미노출 / previousIcon null 시 미노출) | `app/test/features/challenge_space/screens/challenge_space_screen_test.dart` |

`_detail()` 헬퍼에도 `previousIcon` / `iconChangedAt` named params 추가, 기존 호출 (icon-only) 은 default null 로 backward-compat.

## Verification

### 백엔드 — 전체 회귀 + alembic head

```
$ cd /Users/yumunsang/haeda/server && uv run --extra dev python -m pytest tests/test_challenges.py -k "history or icon_change" -v 2>&1 | tail -5
test_icon_change_records_previous_and_metadata PASSED
test_icon_change_overwrites_previous_on_second_change PASSED
test_non_icon_settings_change_does_not_touch_history PASSED
3 passed, 15 deselected in 0.11s

$ uv run --extra dev python -m pytest 2>&1 | tail -3
188 passed in 5.98s   # 직전 baseline 185 + 신규 3

$ docker compose -p feature exec backend uv run alembic current
024 (head)

$ curl -fsS http://localhost:8000/health
{"status":"ok"}
```

### 프론트엔드 — 전체 회귀

```
$ flutter test test/features/challenge_space/screens/challenge_space_screen_test.dart 2>&1 | tail -7
+1: AppBar 에 detail.icon 이 노출된다
+2: creator 가 헤더 이모지 탭 시 EmojiEditSheet 가 열린다
+3: 비-creator 가 헤더 이모지 탭 시 sheet 가 열리지 않는다
+4: 24h 이내 변경 시 이모지 좌측에 previous hint chip 이 노출된다
+5: 24h 초과 시 hint chip 미노출
+6: previousIcon null 시 hint chip 미노출
All tests passed!

$ flutter test 2>&1 | tail -3
00:09 +171: All tests passed!   # 직전 baseline 168 + 본 작업 net +3
```

### iOS 시뮬레이터 — clean install + launch

iPhone 17 (iOS 26.4) terminate → uninstall → flutter clean → pub get → build ios --simulator (✓ Built in 38.9s) → install → launch (PID 45034). my-page 진입 정상.

| # | 시나리오 | 스크린샷 |
|---|---------|---------|
| 1 | 박지민 my-page launch (회귀 baseline 유지, hint chip 노출은 챌린지방 진입 시) | `2026-05-30-feature-icon-change-history-01-launch.png` |

idb HID → Flutter GestureDetector 미인식 한계 변함 없음. 헤더 hint chip 시각 검증은 위젯 테스트 3개로 갈음:
- 24h 이내: `find.byKey(Key('icon_change_hint'))` 노출 + previous emoji 표시
- 24h 초과: 미노출
- previousIcon null: 미노출

24h 윈도우 계산은 `DateTime.now().toUtc().difference(iconChangedAt) < Duration(hours: 24)`.

## Follow-ups

- **patrol/integration_test 도입** (Polish 메뉴 #3) — 시뮬레이터 자동 인터랙션 강화. 다음 polish 작업 후보.
- **이력 1건 이상 보존이 필요해지면 challenge_events 테이블 도입** — 현재 last-1 보존이 MVP 범위. 사용자가 "변경 타임라인" 요구 시 audit log 패턴으로 전환.
- **hint chip 자체 탭 → 변경 컨텍스트 모달** — 누가 언제 바꿨는지 자세히. icon_changed_by_user_id 를 UserBrief 로 해석해 노출. P2.
- **알림 통합** — creator 가 이모지 바꾸면 다른 멤버에게 notifications 항목 추가. P2.

## Related

- 직전 보고서: `docs/reports/2026-05-30-feature-category-aware-presets.md` / `2026-05-30-feature-challenge-icon-followups.md`
- 신규 마이그레이션: `024_add_challenge_icon_history`
- 확장된 모델: `Challenge.previous_icon` / `icon_changed_at` / `icon_changed_by_user_id`
- 확장된 응답: `ChallengeDetail.previous_icon` 등 3 필드
- 신규 위젯: `_IconChangeHint` (`challenge_space_screen.dart`)
