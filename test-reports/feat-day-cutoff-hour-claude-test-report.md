# feat-day-cutoff-hour Test Report

> Last updated: 2026-04-12
> Verdict: **Complete**

## Feature Overview

| Item | Content |
|------|---------|
| Feature | feat-day-cutoff-hour |
| Goal | 유저별 하루 경계 시각(0~2시) 설정 — 새벽 인증을 전날 미션으로 인정 |
| Related impl-log | impl-log/feat-day-cutoff-hour-claude.md |
| Type | P0 cross-layer (server + app) |

## Implementation Scope

### Backend Endpoints

| Endpoint | Status | Notes |
|----------|--------|-------|
| PUT /auth/profile | Updated | day_cutoff_hour 폼 필드 추가, INVALID_DAY_CUTOFF_HOUR 에러 신설 |
| GET /me | Updated | day_cutoff_hour 응답 포함 |
| POST /auth/kakao | Updated | 로그인 응답 user 객체에 day_cutoff_hour 포함 |
| POST /verifications | Updated | effective_today_kst(cutoff_hour) 로 날짜 계산 |

### Frontend Screens

| Screen | Route | Status |
|--------|-------|--------|
| 설정 화면 | /settings | "하루 경계 시각" ListTile 추가 |
| 인증 화면 | /verify | effectiveToday 계산에 dayCutoffHour 반영 |

## Test Results

### Backend Tests

Command: `cd server && .venv/bin/python -m pytest -v`

| Test File | New Tests | Result |
|-----------|-----------|--------|
| tests/test_time.py | `test_effective_today_midnight`, `test_effective_today_before_cutoff`, `test_effective_today_after_cutoff` | PASS × 3 |
| tests/test_verifications.py | `test_verification_boundary_before_cutoff`, `test_verification_boundary_after_cutoff` | PASS × 2 |
| tests/test_auth.py | `test_update_day_cutoff_hour_valid`, `test_update_day_cutoff_hour_invalid`, `test_update_day_cutoff_hour_out_of_range` | PASS × 3 |
| All other existing tests | (unchanged) | PASS |

**Summary**: 94 passed, 0 failed

New tests breakdown:
- `tests/test_time.py` — 3 tests (effective_today_kst: 자정, cutoff 이전, cutoff 이후)
- `tests/test_verifications.py` — 2 tests (boundary 01:59 → 전날, 02:00 → 당일)
- `tests/test_auth.py` — 3 tests (유효값 저장, 무효 문자열, 범위 초과)

### Frontend Tests

Command: `cd app && flutter test test/core/utils/time_test.dart`

| Test | Result |
|------|--------|
| effectiveTodayKst returns today when hour >= cutoff | PASS |
| effectiveTodayKst returns yesterday when hour < cutoff and cutoff=1 | PASS |
| effectiveTodayKst returns yesterday when hour < cutoff and cutoff=2 | PASS |
| effectiveTodayKst with cutoff=0 always returns today | PASS |
| effectiveTodayKst boundary: exactly at cutoff returns today | PASS |

**Summary**: 5 passed, 0 failed

### Lint

Command: `cd app && flutter analyze`

- Result: 0 new errors introduced by this feature
- Note: `test/features/auth/profile_setup_screen_test.dart` 에 pre-existing mock mismatch error 1건 존재 — 이번 변경과 무관한 기존 문제

### iOS Build

Command: `cd app && flutter build ios --simulator --debug`

- Result: **Built build/ios/iphonesimulator/Runner.app** (success)

## Deploy Verification

| Item | Result | Detail |
|------|--------|--------|
| Backend health | PASS | `curl http://localhost:8000/health` → `{"status":"ok"}` |
| Alembic revision | PASS | HEAD = 014, `add_user_day_cutoff_hour` |
| DB column present | PASS | `day_cutoff_hour INTEGER NOT NULL DEFAULT 0` confirmed |
| iOS Simulator | PASS | iPhone 17 (iOS 26.4) — Runner.app launched |

## Acceptance Criteria

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | 유저가 day_cutoff_hour 0/1/2 중 선택 가능 | PASS | PUT /auth/profile day_cutoff_hour 필드 동작 확인 |
| 2 | cutoff=2, 01:59 KST 인증 → 전날 날짜 | PASS | test_verification_boundary_before_cutoff PASS |
| 3 | cutoff=2, 02:00 KST 인증 → 당일 날짜 | PASS | test_verification_boundary_after_cutoff PASS |
| 4 | 기본값 0 = 기존 동작 유지 | PASS | cutoff=0 always today — time_test PASS |
| 5 | 유효하지 않은 값(3 이상, 음수) → 400 INVALID_DAY_CUTOFF_HOUR | PASS | test_update_day_cutoff_hour_invalid / _out_of_range PASS |
| 6 | 설정 화면에서 "하루 경계 시각" 변경 가능 | PASS | settings_screen.dart ListTile 구현 + iOS build success |
| 7 | Alembic migration 014 적용 | PASS | alembic upgrade head → 014 확인 |

## Issues

### Blocking
- None

### Non-blocking
- `test/features/auth/profile_setup_screen_test.dart` 기존 mock mismatch error — 이번 feature 와 무관, 별도 슬라이스에서 수정 예정

## Verdict

- **Complete**
- **Can proceed to next slice**: Yes
- **Reason**: 모든 백엔드 테스트(94/94), Flutter time 테스트(5/5) 통과. iOS 빌드 성공. 배포 건강 확인 완료. Pre-existing test error 1건은 범위 외.
