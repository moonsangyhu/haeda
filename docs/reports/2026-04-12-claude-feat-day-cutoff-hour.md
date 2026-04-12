# 2026-04-12 feature report — per-user day_cutoff_hour (하루 경계 시각)

**Date**: 2026-04-12
**Worktree (수행)**: feature
**Worktree (영향)**: feature (cross-layer: server + app)
**Role**: claude

## Request

> 사용자가 정한 시간까지는 그 전날로 날짜를 인식할 수 있게 해줘. 예를 들면 새벽 2시를 기준으로 날짜가 변한다고 치면 내가 3월 9일 새벽 1시에 인증한 건 3월 8일자 미션을 한걸로 인식되면 좋겠어.

## Root cause / Context

기존 `verification_service.py` 는 Python `date.today()` (서버 UTC 기준)로 인증 날짜를 결정했다. 새벽 루틴 유저가 오전 1~2시에 인증하면 KST 기준으로도 전날에 해당하지만, 서버는 당일로 처리해 "전날 미션 완료"로 인정받지 못했다. 유저마다 생활 패턴이 달라 고정 cutoff 대신 개인 설정값(0, 1, 2시)을 지원하는 방식으로 해결.

## Actions

### Docs

- `docs/prd.md` — F-13 "하루 경계 시각 설정" 기능 항목 추가 (user 승인 후 Main이 수정)
- `docs/domain-model.md` — User 엔티티에 `day_cutoff_hour INT DEFAULT 0` 추가; `effective_today` 계산 규칙(KST now, now.hour < cutoff_hour → 전날) 명세
- `docs/api-contract.md` — PUT /auth/profile 요청/응답에 `day_cutoff_hour` 추가; 에러 코드 `INVALID_DAY_CUTOFF_HOUR` (400) 신설; POST /verifications `date` 필드 주석 추가

### Backend (`server/`)

| 파일 | 변경 내용 |
|------|---------|
| `app/models/user.py` | `day_cutoff_hour: Mapped[int]` (default 0) 컬럼 추가 |
| `app/schemas/user.py` | `UserBrief`, `UserWithIsNew`, `ProfileUpdateResponse`에 `day_cutoff_hour: int` 추가 |
| `app/services/auth_service.py` | `update_profile()`에 `day_cutoff_hour` 파라미터 추가; 0~2 범위 검증 |
| `app/services/verification_service.py` | 인증 날짜 계산을 `effective_today_kst(cutoff_hour)` 로 교체 |
| `app/routers/auth.py` | PUT /auth/profile 폼 필드에 `day_cutoff_hour: int | None = None` 추가 |
| `app/utils/time.py` | 신설. `effective_today_kst(cutoff_hour: int) -> date` 헬퍼 |
| `alembic/versions/20260412_0001_014_add_user_day_cutoff_hour.py` | ADD COLUMN 마이그레이션 |

### Frontend (`app/`)

| 파일 | 변경 내용 |
|------|---------|
| `lib/features/auth/models/auth_models.dart` | `dayCutoffHour: int` 필드 추가 |
| `lib/features/auth/providers/auth_provider.dart` | `/me` 응답 복원 + `updateDayCutoffHour()` 신규 메서드 |
| `lib/features/settings/screens/settings_screen.dart` | "하루 경계 시각" ListTile 신규 (0/1/2 선택 바텀시트) |
| `lib/features/verification/providers/verification_provider.dart` | `effectiveToday` 계산에 `dayCutoffHour` 반영 |
| `lib/core/utils/time.dart` | 신설. `effectiveTodayKst(int cutoffHour) -> DateTime` 헬퍼 |

## Verification

| 항목 | 결과 |
|------|------|
| Alembic migration 014 | Running upgrade 013 → 014 완료 |
| Backend health | `{"status":"ok"}` (curl http://localhost:8000/health) |
| DB column | `day_cutoff_hour INTEGER NOT NULL DEFAULT 0` 존재 확인 |
| pytest (전체) | 94 passed, 0 failed |
| test_time.py (신규 3건) | PASS — effective_today_kst 경계값 포함 |
| test_verifications.py (신규 2건) | PASS — 01:59 전날 / 02:00 당일 경계 |
| test_auth.py (신규 3건) | PASS — 유효값, 무효값, 범위 초과 |
| flutter test time_test.dart | 5 passed, 0 failed |
| flutter analyze | 0 new errors (기존 pre-existing 1건 무관) |
| flutter build ios --simulator | Built Runner.app (success) |
| iPhone 17 simulator | 앱 실행 확인 (iOS 26.4) |

## Follow-ups

1. `test/features/auth/profile_setup_screen_test.dart` 의 pre-existing mock mismatch error는 이번 feature와 무관한 기존 문제. 별도 슬라이스에서 수정 필요.
2. 설정 화면의 "하루 경계 시각" 타일에서 0/1/2 선택 후 저장되는 흐름의 수동 UX 검증은 유저 재량 (시뮬레이터에서 직접 확인).
3. 다른 워크트리 세션이 있다면 `git fetch origin main && git rebase origin/main` 으로 sync 필요 (`.claude/` 변경 없으므로 세션 재시작은 불필요).

## Related

- Approved plan: `/Users/yumunsang/.claude/plans/breezy-prancing-noodle.md`
- impl-log: `impl-log/feat-day-cutoff-hour-claude.md`
- test-report: `test-reports/feat-day-cutoff-hour-claude-test-report.md`
