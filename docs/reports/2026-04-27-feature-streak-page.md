# 연속 기록 페이지 (/streak) 구현

- **Date**: 2026-04-27
- **Worktree (수행)**: `.claude/worktrees/feature` (worktree-feature)
- **Worktree (영향)**: feature 단독 (full-stack)
- **Role**: feature

## Request

> 어플리케이션 위에 연속 기록, 돈을 누르면 관련 페이지가 나와야 해. 연속 기록부터 우선 구현해보자. 연속 기록을 누르면 내가 며칠 연속 챌린지를 달성했는지 맨 위에 크게 강조되어 나오고, 그 밑에는 연속 챌린지 달력이 나와서 실패한 날짜에는 파란색 얼음으로 실패가 강조되어야 해.

## Root cause / Context

상단 `StatusBar` 의 streak pill (`fire/sleep + 일수`) 은 표시만 가능하고 탭 인터랙션이 없었다. 또한 유저 단위 일자별 인증 여부를 보여주는 화면 자체가 부재 — 챌린지별 캘린더(`/challenges/{id}/calendar`) 만 존재. 동기부여(streak 유지) + 회고(어디서 끊겼는지) 양쪽 충족하는 전용 페이지가 필요했다.

## Actions

### 1. 사전 산출물

- 디자인 spec — `docs/superpowers/specs/2026-04-27-streak-page-design.md` (commit `db475a1`)
- 구현 plan — `docs/superpowers/plans/2026-04-27-streak-page.md` (commit `62e40d4`), 17-task TDD 사이클

### 2. 백엔드 (FastAPI + SQLAlchemy 2.0 async)

| Commit | 변경 |
|---|---|
| `0ba4aa8` | `server/app/schemas/streak_calendar.py` — `StreakCalendarResponse` / `StreakDay` / `DayStatus` enum (5 종) |
| `f4aed4f` | `server/app/services/streak_calendar_service.py` — `get_calendar(year, month)` + `_classify` 로직. 첫 테스트 (미참여 유저) 통과 |
| `ea2e5cb` | 4 추가 service 테스트 (어제 인증, 오늘 인증, 같은 날 두 챌린지, 미래 가입) |
| `16afb64` | `server/app/routers/me.py` — `GET /me/streak/calendar?year=&month=` 라우트 + 4 통합 테스트 (200 / 400 INVALID_MONTH × 2 / 401) |
| `793e75e` | `docs/api-contract.md` — 신규 엔드포인트 계약 추가 |

신규 endpoint 응답 예:
```json
{ "data": { "streak": 14, "first_join_date": "2025-12-03", "year": 2026, "month": 4,
  "days": [ {"date": "2026-04-26", "status": "success"}, {"date": "2026-04-27", "status": "today_pending"} ] } }
```

`status` 분류 (코드 `_classify`):
- `date > today` → `future`
- `first_join_date is None` 또는 `date < first_join_date` → `before_join`
- `date in verified_dates` → `success`
- `date == today` → `today_pending`
- 그 외 (`date < today`, no verification) → `failure`

### 3. 프론트엔드 (Flutter + Riverpod + GoRouter + freezed)

| Commit | 변경 |
|---|---|
| `0656a29` | `app/assets/icons/ice.svg` — 파란 얼음 결정 SVG (실패 표시용, color `#4FC3F7`) |
| `efe43c3` | `app/lib/features/streak/models/{day_status,streak_calendar}.dart` — enum + freezed |
| `a3a1b50` | `app/lib/features/streak/providers/streak_calendar_provider.dart` — `FutureProvider.family<StreakCalendar, ({int year, int month})>` |
| `610c6eb` | `app/lib/features/streak/widgets/streak_header.dart` — 큰 streak 숫자 + "일 연속" + 2 위젯 테스트 |
| `9a4c648` | `app/lib/features/streak/widgets/streak_calendar_grid.dart` — 6×7 그리드 + 월 nav (좌우 화살표, 미래 월 차단) + 4 위젯 테스트 |
| `dfa4a79` | `app/lib/features/streak/screens/streak_screen.dart` — `ConsumerStatefulWidget`, `_currentMonth` state |
| `ca6d3da` | `app/lib/app.dart` — `/streak` GoRoute 추가 |
| `9c9e36b` | `app/lib/features/status_bar/widgets/status_bar.dart` — streak pill 만 `Material+InkWell` 로 감싸 `context.push('/streak')`. 다른 pill 미변경. 1 신규 tap 테스트 |

### 4. 통합 검증

- Docker compose rebuild + `/health` 200
- pytest: streak_calendar 9개 + 사전 결함 무관 145개 통과 (151 total — `TestSignature` 6개는 사전 결함, 무관)
- flutter test: 신규 7 테스트 (StreakHeader 2 + Grid 4 + StatusBar tap 1) 모두 GREEN. 사전 결함 7개 (status_bar emoji 5 + profile_setup mock 1 + step1 1) 무관
- `dart analyze lib/features/streak/ test/features/streak/` → No issues
- iOS simulator clean install → 시각 검증 5단계 모두 통과

## Verification

### 백엔드

```
$ cd server && .venv/bin/python -m pytest tests/test_streak_calendar.py -v
tests/test_streak_calendar.py::test_no_membership_user_all_before_join PASSED
tests/test_streak_calendar.py::test_yesterday_verified_is_success PASSED
tests/test_streak_calendar.py::test_today_verified_is_success PASSED
tests/test_streak_calendar.py::test_same_day_two_challenges_one_success PASSED
tests/test_streak_calendar.py::test_join_date_future_to_queried_month PASSED
tests/test_streak_calendar.py::test_endpoint_returns_calendar PASSED
tests/test_streak_calendar.py::test_endpoint_invalid_month_returns_400 PASSED
tests/test_streak_calendar.py::test_endpoint_invalid_year_returns_400 PASSED
tests/test_streak_calendar.py::test_endpoint_no_token_returns_401 PASSED
9 passed in 0.21s

$ docker compose up --build -d backend && curl -fsS http://localhost:8000/health
{"status":"ok"}
```

### 프론트엔드 (단위 테스트)

```
$ flutter test test/features/streak/widgets/streak_header_test.dart
+2: All tests passed!
$ flutter test test/features/streak/widgets/streak_calendar_grid_test.dart
+4: All tests passed!
$ flutter test test/features/status_bar/widgets/status_bar_test.dart --plain-name "tapping streak pill"
+1: All tests passed!
```

### 시뮬레이터 시각 검증 (iPhone 17 Pro, iOS 26.4)

| # | 시나리오 | 스크린샷 | 결과 |
|---|---------|---------|------|
| 1 | 앱 launch → 내 페이지 (StatusBar 의 🔥2 pill 보임) | `docs/reports/screenshots/2026-04-27-feature-streak-page-01-launch.png` | ✅ |
| 2 | streak pill 탭 → `/streak` 진입, 큰 "2" + "일 연속" + 4월 캘린더, 4/26·27 🔥, 4/27 굵은 테두리, 1-25/28-30 흐림 | `2026-04-27-feature-streak-page-02-after-tap.png` | ✅ |
| 3 | 좌 화살표 → 3월 이동, 모든 날짜 흐림 (가입 전), 우 화살표 활성 | `2026-04-27-feature-streak-page-03-prev-month.png` | ✅ |
| 4 | 우 화살표 → 4월 복귀, 우 화살표 비활성 (현재 월) | `2026-04-27-feature-streak-page-04-next-month-back.png` | ✅ |
| 5 | 뒤로가기 → 내 페이지 복귀 | `2026-04-27-feature-streak-page-05-back-to-my-page.png` | ✅ |

(현재 시뮬레이터 데이터 = 가입일 4/26 + 4/26·27 두 날 모두 인증. 따라서 ❄ failure 셀은 이번 검증에서 표시되지 않음. 코드 경로는 `_classify` 의 `return DayStatus.FAILURE` 분기 + grid `_statusIcon` 의 `case DayStatus.failure: return SvgPicture.asset('assets/icons/ice.svg')` 로 검증됨 — pytest + flutter test 통과.)

## Follow-ups

- **돈 (gem) pill 탭 페이지** — 사용자 원 요청에 포함되었으나 streak 우선 합의 → 후속 슬라이스. 같은 패턴 (StatusBar 의 gem pill 을 `InkWell` 로 감싸 `/gems` push) 적용 권장.
- **챌린지 (lightning) pill 탭 페이지** — 미정. 사용자 요청 시 동일 패턴 확장.
- **Provider 캐싱 정책** — 현재 `streakCalendarProvider.family` 는 매 진입 fetch. 인증 mutation 후 stale 우려 시 `ref.invalidate(streakCalendarProvider)` 훅을 verification submit 흐름에 추가.
- **사전 결함 (이번 작업 무관)**:
  - `app/test/features/status_bar/widgets/status_bar_test.dart` 의 emoji 기반 5 테스트가 SVG 전환 후 실패 상태. 별도 정리 필요.
  - `app/test/features/auth/screens/profile_setup_screen_test.dart` mock signature mismatch.
  - `server/tests/test_room_equip.py::TestSignature` 6개 — 422 응답으로 실패. 별도 진단 필요.
- **상단 UI 강조** — 사용자가 (a) 미니멀 (숫자만) 선택. 추후 (b) 최고 기록 / (c) 캐릭터 확장 여지.

## Related

- Spec: `docs/superpowers/specs/2026-04-27-streak-page-design.md`
- Plan: `docs/superpowers/plans/2026-04-27-streak-page.md`
- 신규 endpoint: `docs/api-contract.md` §3 GET `/me/streak/calendar`
- StatusBar 변경: `app/lib/features/status_bar/widgets/status_bar.dart`
- 신규 모듈: `app/lib/features/streak/`, `server/app/services/streak_calendar_service.py`
