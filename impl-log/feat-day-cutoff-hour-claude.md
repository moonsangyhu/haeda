# feat: per-user day_cutoff_hour (하루 경계 시각)

**Date**: 2026-04-12
**Worktree**: feature (cross-layer)
**Scope**: server + app + docs

## Goal

유저가 "하루 경계 시각"을 0, 1, 2시 중 선택할 수 있게 하여, 새벽 인증을 전날 미션으로 인정받을 수 있게 한다. cutoff=2 일 때 01:59 KST 인증은 전날, 02:00 KST 인증은 당일로 집계된다. 기본값 0은 기존 동작과 동일.

## Scope

- Backend: users 테이블, PUT /auth/profile, verification date 계산
- Frontend: 설정 화면 "하루 경계 시각" 타일, verification provider effectiveToday
- Docs: domain-model §2.1 (User.day_cutoff_hour + effective_today 규칙), api-contract (PUT /auth/profile + INVALID_DAY_CUTOFF_HOUR + verifications date 주석), prd.md F-13

## Changes

### Backend (`server/`)

- `app/models/user.py` — `day_cutoff_hour: Mapped[int]` (default 0, 0~2 범위) 컬럼 추가
- `app/schemas/user.py` — `UserBrief`, `UserWithIsNew`, `ProfileUpdateResponse`에 `day_cutoff_hour: int` 추가
- `app/services/auth_service.py` — `update_profile()` 에 `day_cutoff_hour: int | None = None` 파라미터 추가; 0~2 범위 검증, 위반 시 `INVALID_DAY_CUTOFF_HOUR` 400
- `app/services/verification_service.py` — 인증 날짜 계산 시 `utils.time.effective_today_kst(cutoff_hour)` 사용으로 교체
- `app/routers/auth.py` — PUT `/auth/profile` 폼 필드에 `day_cutoff_hour: int | None = None` 추가
- `app/utils/time.py` — 신설. `effective_today_kst(cutoff_hour: int) -> date` 헬퍼 구현 (KST now, 자정~cutoff_hour 미만이면 전날 반환)
- `alembic/versions/20260412_0001_014_add_user_day_cutoff_hour.py` — ADD COLUMN `day_cutoff_hour INTEGER NOT NULL DEFAULT 0` 마이그레이션

### Frontend (`app/`)

- `lib/features/auth/models/auth_models.dart` — `AuthUser`, `ProfileUpdateData`에 `dayCutoffHour: int` 필드 추가 (build_runner 재생성)
- `lib/features/auth/providers/auth_provider.dart` — `checkAuthOnStartup()`에서 `/me` 응답의 `day_cutoff_hour` 복원; `updateDayCutoffHour(int hour)` 신규 메서드 추가
- `lib/features/settings/screens/settings_screen.dart` — "하루 경계 시각" ListTile 신규 — 0/1/2 선택 바텀시트, 현재값 표시, `updateDayCutoffHour()` 호출
- `lib/features/verification/providers/verification_provider.dart` — `effectiveToday` 계산에 `dayCutoffHour` 반영 (KST now, cutoff 이전이면 어제 반환)
- `lib/core/utils/time.dart` — 신설. Flutter 측 `effectiveTodayKst(int cutoffHour) -> DateTime` 헬퍼

## Migration

- Alembic revision: `014` (20260412_0001_014_add_user_day_cutoff_hour)
- 업그레이드: `ADD COLUMN day_cutoff_hour INTEGER NOT NULL DEFAULT 0`
- 다운그레이드: `DROP COLUMN day_cutoff_hour`

## API Changes

`docs/api-contract.md` 변경 요약:
- PUT `/auth/profile` 요청 폼 필드에 `day_cutoff_hour?: 0 | 1 | 2` 추가
- PUT `/auth/profile` 응답 `user` 객체에 `day_cutoff_hour: int` 포함
- 에러 코드 `INVALID_DAY_CUTOFF_HOUR` (400) 신설
- POST `/verifications` `date` 필드 주석: "KST effective date accounting for day_cutoff_hour" 추가

## Rollback Steps

1. `cd server && alembic downgrade 013` — `day_cutoff_hour` 컬럼 제거
2. `git revert <feat-day-cutoff-hour 커밋 해시>` 또는 아래 파일 수동 복원:
   - `server/app/models/user.py`
   - `server/app/schemas/user.py`
   - `server/app/services/auth_service.py`
   - `server/app/services/verification_service.py`
   - `server/app/routers/auth.py`
   - `server/app/utils/time.py` (삭제)
   - `server/alembic/versions/20260412_0001_014_*.py` (삭제)
   - `app/lib/features/auth/models/auth_models.dart`
   - `app/lib/features/auth/providers/auth_provider.dart`
   - `app/lib/features/settings/screens/settings_screen.dart`
   - `app/lib/features/verification/providers/verification_provider.dart`
   - `app/lib/core/utils/time.dart` (삭제)
3. `docker compose up --build -d backend` — 롤백 상태로 재빌드
