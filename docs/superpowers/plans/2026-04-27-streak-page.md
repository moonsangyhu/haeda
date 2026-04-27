# 연속 기록 페이지 (Streak Page) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 상태바 streak pill 을 탭하면 큰 streak 숫자 + 월별 캘린더(성공=🔥/실패=❄)가 표시되는 풀스크린 `/streak` 페이지를 추가한다.

**Architecture:**
- 백엔드: 신규 `GET /me/streak/calendar?year=Y&month=M` 엔드포인트, `streak_calendar_service` 가 (DISTINCT verification dates) + `MIN(challenge_members.joined_at)` + 전역 streak 을 합쳐서 응답.
- 프론트엔드: 신규 `features/streak/` 모듈 (model + provider + screen + 2 widget). `app.dart` 에 `/streak` route 추가. `StatusBar` streak pill 을 `InkWell` 로 감싼다.
- 신규 `assets/icons/ice.svg` (파란 얼음 결정).

**Tech Stack:** FastAPI + SQLAlchemy 2.0 async + Pydantic v2 / Flutter + Riverpod + GoRouter + dio + freezed + flutter_svg.

**스펙 참조:** `docs/superpowers/specs/2026-04-27-streak-page-design.md`

---

## File Structure

**백엔드 (server/):**
- Create: `server/app/schemas/streak_calendar.py` — Pydantic 응답 schema + DayStatus enum
- Create: `server/app/services/streak_calendar_service.py` — get_calendar 함수
- Create: `server/tests/test_streak_calendar.py` — 서비스 + 라우터 통합 테스트
- Modify: `server/app/routers/me.py` — `/streak/calendar` 라우트 추가

**프론트엔드 (app/):**
- Create: `app/assets/icons/ice.svg` — 파란 얼음 SVG
- Create: `app/lib/features/streak/models/day_status.dart` — DayStatus enum
- Create: `app/lib/features/streak/models/streak_calendar.dart` — freezed StreakCalendar / StreakDay
- Create: `app/lib/features/streak/providers/streak_calendar_provider.dart` — FutureProvider.family
- Create: `app/lib/features/streak/widgets/streak_header.dart` — 큰 숫자 + 라벨
- Create: `app/lib/features/streak/widgets/streak_calendar_grid.dart` — 6×7 그리드 + 월 nav
- Create: `app/lib/features/streak/screens/streak_screen.dart` — 풀스크린 페이지
- Create: `app/test/features/streak/widgets/streak_header_test.dart`
- Create: `app/test/features/streak/widgets/streak_calendar_grid_test.dart`
- Modify: `app/lib/features/status_bar/widgets/status_bar.dart` — streak pill InkWell
- Modify: `app/lib/app.dart` — `/streak` GoRoute 추가
- Modify: `app/test/features/status_bar/widgets/status_bar_test.dart` — pill 탭 테스트

**Docs:**
- Modify: `docs/api-contract.md` — `/me/streak/calendar` 엔드포인트 추가

---

## Task 1: Pydantic Schema (StreakCalendarResponse)

**Files:**
- Create: `server/app/schemas/streak_calendar.py`

- [ ] **Step 1: Create the schema file**

```python
# server/app/schemas/streak_calendar.py
from datetime import date
from enum import Enum

from pydantic import BaseModel


class DayStatus(str, Enum):
    SUCCESS = "success"
    FAILURE = "failure"
    TODAY_PENDING = "today_pending"
    FUTURE = "future"
    BEFORE_JOIN = "before_join"


class StreakDay(BaseModel):
    date: date
    status: DayStatus


class StreakCalendarResponse(BaseModel):
    streak: int
    first_join_date: date | None
    year: int
    month: int
    days: list[StreakDay]
```

- [ ] **Step 2: Verify import works**

Run: `cd server && python -c "from app.schemas.streak_calendar import StreakCalendarResponse, DayStatus; print('ok')"`
Expected: `ok`

- [ ] **Step 3: Commit**

```bash
git add server/app/schemas/streak_calendar.py
git commit -m "feat(server): streak calendar 응답 schema 추가"
```

---

## Task 2: Service — 챌린지 미참여 유저 (RED)

**Files:**
- Create: `server/tests/test_streak_calendar.py`
- Create: `server/app/services/streak_calendar_service.py`

- [ ] **Step 1: Write the failing test**

```python
# server/tests/test_streak_calendar.py
"""GET /me/streak/calendar — 전역 streak 캘린더 테스트"""
import uuid
from datetime import date, datetime
from unittest.mock import patch

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.challenge import Challenge
from app.models.challenge_member import ChallengeMember
from app.models.user import User
from app.models.verification import Verification
from app.schemas.streak_calendar import DayStatus
from app.services import streak_calendar_service


@pytest.mark.asyncio
async def test_no_membership_user_all_before_join(
    db_session: AsyncSession, user: User
):
    """챌린지 미참여 유저: first_join_date=None, 모든 날짜 before_join."""
    today = date(2026, 4, 27)
    with patch("app.services.streak_calendar_service._today", return_value=today):
        result = await streak_calendar_service.get_calendar(
            db=db_session, user_id=user.id, year=2026, month=4
        )

    assert result.streak == 0
    assert result.first_join_date is None
    assert result.year == 2026
    assert result.month == 4
    assert len(result.days) == 30
    # 4/27 까지는 before_join, 4/28~ 은 future
    past = [d for d in result.days if d.date <= today]
    future = [d for d in result.days if d.date > today]
    assert all(d.status == DayStatus.BEFORE_JOIN for d in past)
    assert all(d.status == DayStatus.FUTURE for d in future)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && python -m pytest tests/test_streak_calendar.py::test_no_membership_user_all_before_join -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'app.services.streak_calendar_service'`

- [ ] **Step 3: Write minimal implementation**

```python
# server/app/services/streak_calendar_service.py
import calendar as cal_lib
import uuid
from datetime import date

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.challenge_member import ChallengeMember
from app.models.verification import Verification
from app.schemas.streak_calendar import DayStatus, StreakCalendarResponse, StreakDay
from app.services import user_stats_service


def _today() -> date:
    return date.today()


async def get_calendar(
    db: AsyncSession,
    user_id: uuid.UUID,
    year: int,
    month: int,
) -> StreakCalendarResponse:
    today = _today()

    join_stmt = select(func.min(ChallengeMember.joined_at)).where(
        ChallengeMember.user_id == user_id
    )
    join_result = await db.execute(join_stmt)
    earliest_joined = join_result.scalar_one_or_none()
    first_join_date = earliest_joined.date() if earliest_joined is not None else None

    streak, _verified_today = await user_stats_service.calculate_global_streak(
        db, user_id
    )

    last_day = cal_lib.monthrange(year, month)[1]
    month_start = date(year, month, 1)
    month_end = date(year, month, last_day)

    verified_dates: set[date] = set()
    if first_join_date is not None:
        v_stmt = (
            select(Verification.date)
            .where(
                Verification.user_id == user_id,
                Verification.date >= month_start,
                Verification.date <= month_end,
            )
            .distinct()
        )
        v_result = await db.execute(v_stmt)
        verified_dates = {row[0] for row in v_result.all()}

    days: list[StreakDay] = []
    for day_num in range(1, last_day + 1):
        d = date(year, month, day_num)
        days.append(StreakDay(date=d, status=_classify(d, today, first_join_date, verified_dates)))

    return StreakCalendarResponse(
        streak=streak,
        first_join_date=first_join_date,
        year=year,
        month=month,
        days=days,
    )


def _classify(
    d: date,
    today: date,
    first_join_date: date | None,
    verified_dates: set[date],
) -> DayStatus:
    if d > today:
        return DayStatus.FUTURE
    if first_join_date is None or d < first_join_date:
        return DayStatus.BEFORE_JOIN
    if d in verified_dates:
        return DayStatus.SUCCESS
    if d == today:
        return DayStatus.TODAY_PENDING
    return DayStatus.FAILURE
```

Then register the new module in `server/app/services/__init__.py` if needed:

```bash
grep -q "streak_calendar_service" server/app/services/__init__.py || \
  echo "from app.services import streak_calendar_service  # noqa: F401" >> server/app/services/__init__.py
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd server && python -m pytest tests/test_streak_calendar.py::test_no_membership_user_all_before_join -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/app/services/streak_calendar_service.py server/app/services/__init__.py server/tests/test_streak_calendar.py
git commit -m "feat(server): streak_calendar_service — 미참여 유저 처리"
```

---

## Task 3: Service — 가입 후 success / failure / today_pending 케이스

**Files:**
- Modify: `server/tests/test_streak_calendar.py`

- [ ] **Step 1: Add failing tests**

Append to `server/tests/test_streak_calendar.py`:

```python
@pytest.mark.asyncio
async def test_yesterday_verified_is_success(
    db_session: AsyncSession,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    """어제 인증 → success. 오늘 인증 X → today_pending."""
    today = date(2026, 4, 27)
    yesterday = date(2026, 4, 26)

    # membership.joined_at 는 server_default=now() — 명시적으로 과거로 설정
    membership.joined_at = datetime(2026, 4, 1, 0, 0, 0)
    db_session.add(
        Verification(
            id=uuid.uuid4(),
            challenge_id=challenge.id,
            user_id=user.id,
            date=yesterday,
            photo_urls=None,
            diary_text="어제 운동",
        )
    )
    await db_session.commit()

    with patch("app.services.streak_calendar_service._today", return_value=today):
        result = await streak_calendar_service.get_calendar(
            db=db_session, user_id=user.id, year=2026, month=4
        )

    by_date = {d.date: d.status for d in result.days}
    assert by_date[yesterday] == DayStatus.SUCCESS
    assert by_date[today] == DayStatus.TODAY_PENDING
    # 4/2~4/25 (가입 후, 인증 없음) → failure
    assert by_date[date(2026, 4, 2)] == DayStatus.FAILURE
    assert by_date[date(2026, 4, 25)] == DayStatus.FAILURE
    # 4/1 (가입일 자체) → 인증 없음 + 과거 → failure
    assert by_date[date(2026, 4, 1)] == DayStatus.FAILURE
    # 미래
    assert by_date[date(2026, 4, 30)] == DayStatus.FUTURE


@pytest.mark.asyncio
async def test_today_verified_is_success(
    db_session: AsyncSession,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    """오늘 인증 완료 → today 도 success."""
    today = date(2026, 4, 27)
    membership.joined_at = datetime(2026, 4, 1, 0, 0, 0)
    db_session.add(
        Verification(
            id=uuid.uuid4(),
            challenge_id=challenge.id,
            user_id=user.id,
            date=today,
            photo_urls=None,
            diary_text="오늘 운동",
        )
    )
    await db_session.commit()

    with patch("app.services.streak_calendar_service._today", return_value=today):
        result = await streak_calendar_service.get_calendar(
            db=db_session, user_id=user.id, year=2026, month=4
        )

    by_date = {d.date: d.status for d in result.days}
    assert by_date[today] == DayStatus.SUCCESS


@pytest.mark.asyncio
async def test_same_day_two_challenges_one_success(
    db_session: AsyncSession,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    """같은 날 두 챌린지 인증 → 한 칸만 success."""
    today = date(2026, 4, 27)
    yesterday = date(2026, 4, 26)
    membership.joined_at = datetime(2026, 4, 1, 0, 0, 0)

    challenge2 = Challenge(
        id=uuid.uuid4(),
        creator_id=user.id,
        title="독서",
        description="매일 독서",
        category="공부",
        start_date=date(2026, 4, 1),
        end_date=date(2026, 4, 30),
        verification_frequency={"type": "daily"},
        photo_required=False,
        invite_code="WXYZ9999",
        status="active",
    )
    db_session.add(challenge2)
    await db_session.flush()
    db_session.add(
        ChallengeMember(
            id=uuid.uuid4(),
            challenge_id=challenge2.id,
            user_id=user.id,
            joined_at=datetime(2026, 4, 1, 0, 0, 0),
        )
    )
    db_session.add_all(
        [
            Verification(
                id=uuid.uuid4(),
                challenge_id=challenge.id,
                user_id=user.id,
                date=yesterday,
                photo_urls=None,
                diary_text="운동",
            ),
            Verification(
                id=uuid.uuid4(),
                challenge_id=challenge2.id,
                user_id=user.id,
                date=yesterday,
                photo_urls=None,
                diary_text="독서",
            ),
        ]
    )
    await db_session.commit()

    with patch("app.services.streak_calendar_service._today", return_value=today):
        result = await streak_calendar_service.get_calendar(
            db=db_session, user_id=user.id, year=2026, month=4
        )

    by_date = {d.date: d.status for d in result.days}
    assert by_date[yesterday] == DayStatus.SUCCESS
    success_count = sum(1 for s in by_date.values() if s == DayStatus.SUCCESS)
    assert success_count == 1


@pytest.mark.asyncio
async def test_join_date_future_to_queried_month(
    db_session: AsyncSession,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    """가입일이 조회 월보다 미래 → 모든 날짜 before_join."""
    today = date(2026, 4, 27)
    membership.joined_at = datetime(2026, 5, 10, 0, 0, 0)  # 5월 가입
    await db_session.commit()

    with patch("app.services.streak_calendar_service._today", return_value=today):
        result = await streak_calendar_service.get_calendar(
            db=db_session, user_id=user.id, year=2026, month=4
        )

    assert all(
        d.status in (DayStatus.BEFORE_JOIN, DayStatus.FUTURE) for d in result.days
    )
```

- [ ] **Step 2: Run all service tests**

Run: `cd server && python -m pytest tests/test_streak_calendar.py -v`
Expected: PASS — 5 passed (1 from Task 2 + 4 from Task 3)

(`_classify` 로직이 이미 모든 케이스를 처리하므로 새 코드 변경 없이 그린.)

- [ ] **Step 3: Commit**

```bash
git add server/tests/test_streak_calendar.py
git commit -m "test(server): streak_calendar_service success/failure/today_pending 케이스"
```

---

## Task 4: 라우터 — `GET /me/streak/calendar`

**Files:**
- Modify: `server/app/routers/me.py`
- Modify: `server/tests/test_streak_calendar.py`

- [ ] **Step 1: Write the failing endpoint test**

Append to `server/tests/test_streak_calendar.py`:

```python
@pytest.mark.asyncio
async def test_endpoint_returns_calendar(
    client: AsyncClient,
    db_session: AsyncSession,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    membership.joined_at = datetime(2026, 4, 1, 0, 0, 0)
    db_session.add(
        Verification(
            id=uuid.uuid4(),
            challenge_id=challenge.id,
            user_id=user.id,
            date=date(2026, 4, 26),
            photo_urls=None,
            diary_text="운동",
        )
    )
    await db_session.commit()

    with patch("app.services.streak_calendar_service._today", return_value=date(2026, 4, 27)):
        resp = await client.get(
            "/api/v1/me/streak/calendar?year=2026&month=4",
            headers={"Authorization": f"Bearer {user.id}"},
        )

    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["year"] == 2026
    assert data["month"] == 4
    assert data["first_join_date"] == "2026-04-01"
    assert len(data["days"]) == 30
    by_date = {d["date"]: d["status"] for d in data["days"]}
    assert by_date["2026-04-26"] == "success"
    assert by_date["2026-04-27"] == "today_pending"


@pytest.mark.asyncio
async def test_endpoint_invalid_month_returns_400(
    client: AsyncClient, user: User
):
    resp = await client.get(
        "/api/v1/me/streak/calendar?year=2026&month=13",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 400
    body = resp.json()
    assert body["error"]["code"] == "INVALID_MONTH"


@pytest.mark.asyncio
async def test_endpoint_invalid_year_returns_400(
    client: AsyncClient, user: User
):
    resp = await client.get(
        "/api/v1/me/streak/calendar?year=1900&month=4",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 400
    body = resp.json()
    assert body["error"]["code"] == "INVALID_MONTH"


@pytest.mark.asyncio
async def test_endpoint_no_token_returns_401(client: AsyncClient):
    resp = await client.get("/api/v1/me/streak/calendar?year=2026&month=4")
    assert resp.status_code == 401
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd server && python -m pytest tests/test_streak_calendar.py -v -k endpoint`
Expected: FAIL — 4 failed (404 / route not found)

- [ ] **Step 3: Add the route + import**

Edit `server/app/routers/me.py`:

Add to imports (`from app.services import …` line):
```python
from app.services import (
    challenge_service,
    character_service,
    gem_service,
    shop_service,
    streak_calendar_service,
    user_stats_service,
)
```

Append at end of file:

```python
@router.get("/streak/calendar")
async def get_streak_calendar(
    year: int = Query(..., description="조회 연도"),
    month: int = Query(..., description="조회 월 (1~12)"),
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    if year < 2024 or year > 2100 or month < 1 or month > 12:
        raise AppException(
            status_code=400,
            code="INVALID_MONTH",
            message="잘못된 연도/월입니다.",
        )
    cal = await streak_calendar_service.get_calendar(
        db=db, user_id=user_id, year=year, month=month
    )
    return {"data": cal.model_dump(mode="json")}
```

`mode="json"` 으로 직렬화하면 `date` 객체가 ISO 문자열, enum 이 값(`"success"` 등) 으로 나간다.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd server && python -m pytest tests/test_streak_calendar.py -v`
Expected: PASS — 9 passed (5 service + 4 endpoint)

- [ ] **Step 5: Commit**

```bash
git add server/app/routers/me.py server/tests/test_streak_calendar.py
git commit -m "feat(server): GET /me/streak/calendar 엔드포인트"
```

---

## Task 5: API 계약 문서 업데이트

**Files:**
- Modify: `docs/api-contract.md`

- [ ] **Step 1: 기존 `/me/stats` 섹션 위치 확인**

Run: `grep -n "GET .*me/stats\|GET .*me/coins\b" docs/api-contract.md`
Expected: line numbers showing `/me/stats` 섹션. 그 직후 (또는 `/me/coins` 직전) 에 추가한다.

- [ ] **Step 2: 새 섹션 삽입**

`/me/stats` 섹션 끝과 `/me/coins` 섹션 시작 사이에 다음 마크다운을 삽입:

```markdown
### GET `/me/streak/calendar` — 전역 streak 캘린더

전역 streak 의 월별 일자별 상태를 반환한다. 상단 status bar 의 streak pill 탭으로 진입하는 `/streak` 페이지에서 사용.

**Query parameters:**
- `year`: int, 2024 ≤ year ≤ 2100
- `month`: int, 1 ≤ month ≤ 12

**Response (200):**
```json
{
  "data": {
    "streak": 14,
    "first_join_date": "2025-12-03",
    "year": 2026,
    "month": 4,
    "days": [
      { "date": "2026-04-01", "status": "success" },
      { "date": "2026-04-02", "status": "failure" },
      { "date": "2026-04-27", "status": "today_pending" },
      { "date": "2026-04-28", "status": "future" }
    ]
  }
}
```

**필드:**
- `streak`: 현재 전역 streak (`/me/stats` 와 동일 로직)
- `first_join_date`: 유저의 가장 이른 `ChallengeMember.joined_at` 날짜. 챌린지 미참여 시 `null`
- `days`: 해당 월의 모든 날짜, `date` 오름차순 (28~31 개)

**status 값:**
- `success` — 그 날 어떤 챌린지든 인증 1 회 이상
- `failure` — 가입 이후 ~ 어제 사이, 인증 없음
- `today_pending` — 오늘 + 인증 없음 (오늘 인증 완료면 `success` 우선)
- `future` — 오늘 이후
- `before_join` — 첫 챌린지 가입일 이전 (또는 미참여 유저)

**Error:**
- `400 INVALID_MONTH` — year/month 범위 밖
- `401 UNAUTHORIZED` — 토큰 없음
```

- [ ] **Step 3: Commit**

```bash
git add docs/api-contract.md
git commit -m "docs(api): GET /me/streak/calendar 엔드포인트 계약 추가"
```

---

## Task 6: Backend Build Verification

- [ ] **Step 1: Docker rebuild + health check**

Run:
```bash
docker compose up --build -d backend
sleep 3
curl -fsS http://localhost:8000/health
```
Expected: `{"status":"ok"}` (또는 동등) HTTP 200.

실패 시: `docker compose logs --tail=200 backend` 로 원인 확인 후 수정.

- [ ] **Step 2: 새 엔드포인트 smoke test (선택)**

Run (토큰이 있다면):
```bash
curl -s "http://localhost:8000/api/v1/me/streak/calendar?year=2026&month=4" \
  -H "Authorization: Bearer <user-uuid>" | python3 -m json.tool | head -30
```
없으면 skip — pytest 가 보장.

- [ ] **Step 3: 전체 백엔드 테스트**

Run: `cd server && python -m pytest -x -q`
Expected: 전체 통과.

---

## Task 7: 신규 SVG asset (ice.svg)

**Files:**
- Create: `app/assets/icons/ice.svg`

- [ ] **Step 1: 파일 작성**

```bash
cat > app/assets/icons/ice.svg <<'EOF'
<svg width="32" height="32" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
  <g stroke="#4FC3F7" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none">
    <line x1="16" y1="3" x2="16" y2="29"/>
    <line x1="5" y1="9" x2="27" y2="23"/>
    <line x1="27" y1="9" x2="5" y2="23"/>
    <polyline points="13,5 16,8 19,5"/>
    <polyline points="13,27 16,24 19,27"/>
    <polyline points="3,11 6,12 7,9"/>
    <polyline points="29,11 26,12 25,9"/>
    <polyline points="3,21 6,20 7,23"/>
    <polyline points="29,21 26,20 25,23"/>
  </g>
  <circle cx="16" cy="16" r="2.5" fill="#4FC3F7"/>
</svg>
EOF
```

심플한 6 갈래 눈송이 (얼음 결정) — fire.svg 와 같은 32×32 viewBox.

- [ ] **Step 2: Verify asset path**

Run: `ls -la app/assets/icons/ice.svg`
Expected: 파일 존재.

`pubspec.yaml` 은 `assets/icons/` 전체를 등록하므로 추가 변경 불필요.

- [ ] **Step 3: Commit**

```bash
git add app/assets/icons/ice.svg
git commit -m "feat(app): ice.svg 아이콘 추가 (streak failure 표시용)"
```

---

## Task 8: DayStatus enum + 모델

**Files:**
- Create: `app/lib/features/streak/models/day_status.dart`
- Create: `app/lib/features/streak/models/streak_calendar.dart`

- [ ] **Step 1: enum 작성**

```dart
// app/lib/features/streak/models/day_status.dart
import 'package:json_annotation/json_annotation.dart';

enum DayStatus {
  @JsonValue('success')
  success,
  @JsonValue('failure')
  failure,
  @JsonValue('today_pending')
  todayPending,
  @JsonValue('future')
  future,
  @JsonValue('before_join')
  beforeJoin,
}
```

- [ ] **Step 2: freezed 모델 작성**

```dart
// app/lib/features/streak/models/streak_calendar.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'day_status.dart';

part 'streak_calendar.freezed.dart';
part 'streak_calendar.g.dart';

@freezed
class StreakDay with _$StreakDay {
  const factory StreakDay({
    required DateTime date,
    required DayStatus status,
  }) = _StreakDay;

  factory StreakDay.fromJson(Map<String, dynamic> json) =>
      _$StreakDayFromJson(json);
}

@freezed
class StreakCalendar with _$StreakCalendar {
  const factory StreakCalendar({
    required int streak,
    @JsonKey(name: 'first_join_date') DateTime? firstJoinDate,
    required int year,
    required int month,
    required List<StreakDay> days,
  }) = _StreakCalendar;

  factory StreakCalendar.fromJson(Map<String, dynamic> json) =>
      _$StreakCalendarFromJson(json);
}
```

- [ ] **Step 3: build_runner 실행**

Run: `cd app && dart run build_runner build --delete-conflicting-outputs`
Expected: `streak_calendar.freezed.dart` 와 `streak_calendar.g.dart` 생성. 에러 없음.

- [ ] **Step 4: Commit**

```bash
git add app/lib/features/streak/models/
git commit -m "feat(app): StreakCalendar / StreakDay / DayStatus 모델"
```

---

## Task 9: Provider — streakCalendarProvider

**Files:**
- Create: `app/lib/features/streak/providers/streak_calendar_provider.dart`

- [ ] **Step 1: provider 작성**

```dart
// app/lib/features/streak/providers/streak_calendar_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/streak_calendar.dart';

typedef YearMonth = ({int year, int month});

final streakCalendarProvider =
    FutureProvider.family<StreakCalendar, YearMonth>((ref, ym) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(
    '/me/streak/calendar',
    queryParameters: {'year': ym.year, 'month': ym.month},
  );
  // ResponseInterceptor unwraps the "data" envelope
  final data = response.data as Map<String, dynamic>;
  return StreakCalendar.fromJson(data);
});
```

- [ ] **Step 2: 컴파일 확인**

Run: `cd app && dart analyze lib/features/streak/`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add app/lib/features/streak/providers/
git commit -m "feat(app): streakCalendarProvider (FutureProvider.family)"
```

---

## Task 10: StreakHeader 위젯 + 테스트

**Files:**
- Create: `app/lib/features/streak/widgets/streak_header.dart`
- Create: `app/test/features/streak/widgets/streak_header_test.dart`

- [ ] **Step 1: Write the failing widget test**

```dart
// app/test/features/streak/widgets/streak_header_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haeda/features/streak/widgets/streak_header.dart';

void main() {
  testWidgets('renders streak number large + label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StreakHeader(streak: 14)),
      ),
    );

    expect(find.text('14'), findsOneWidget);
    expect(find.text('일 연속'), findsOneWidget);
  });

  testWidgets('renders 0 streak correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StreakHeader(streak: 0)),
      ),
    );
    expect(find.text('0'), findsOneWidget);
    expect(find.text('일 연속'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/streak/widgets/streak_header_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:haeda/features/streak/widgets/streak_header.dart'`

- [ ] **Step 3: Write widget**

```dart
// app/lib/features/streak/widgets/streak_header.dart
import 'package:flutter/material.dart';

class StreakHeader extends StatelessWidget {
  const StreakHeader({super.key, required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$streak',
            style: theme.textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '일 연속',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/streak/widgets/streak_header_test.dart`
Expected: PASS — 2 tests.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/streak/widgets/streak_header.dart app/test/features/streak/widgets/streak_header_test.dart
git commit -m "feat(app): StreakHeader 위젯"
```

---

## Task 11: StreakCalendarGrid 위젯 + 테스트

**Files:**
- Create: `app/lib/features/streak/widgets/streak_calendar_grid.dart`
- Create: `app/test/features/streak/widgets/streak_calendar_grid_test.dart`

- [ ] **Step 1: Write failing widget tests**

```dart
// app/test/features/streak/widgets/streak_calendar_grid_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haeda/features/streak/models/day_status.dart';
import 'package:haeda/features/streak/models/streak_calendar.dart';
import 'package:haeda/features/streak/widgets/streak_calendar_grid.dart';

StreakCalendar _calendar({
  int year = 2026,
  int month = 4,
  List<StreakDay>? days,
}) {
  final daysList = days ??
      [
        StreakDay(date: DateTime(2026, 4, 1), status: DayStatus.success),
        StreakDay(date: DateTime(2026, 4, 2), status: DayStatus.failure),
        StreakDay(date: DateTime(2026, 4, 27), status: DayStatus.todayPending),
        StreakDay(date: DateTime(2026, 4, 30), status: DayStatus.future),
      ];
  return StreakCalendar(
    streak: 1,
    firstJoinDate: DateTime(2026, 4, 1),
    year: year,
    month: month,
    days: daysList,
  );
}

bool _hasSvgWith(WidgetTester tester, String assetSubstring) {
  return tester.widgetList<SvgPicture>(find.byType(SvgPicture)).any(
        (s) => s.bytesLoader.toString().contains(assetSubstring),
      );
}

void main() {
  testWidgets('renders fire.svg for success cells', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreakCalendarGrid(
            calendar: _calendar(),
            onPrevMonth: () {},
            onNextMonth: () {},
          ),
        ),
      ),
    );
    expect(_hasSvgWith(tester, 'fire.svg'), isTrue);
  });

  testWidgets('renders ice.svg for failure cells', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreakCalendarGrid(
            calendar: _calendar(),
            onPrevMonth: () {},
            onNextMonth: () {},
          ),
        ),
      ),
    );
    expect(_hasSvgWith(tester, 'ice.svg'), isTrue);
  });

  testWidgets('next-month arrow disabled when on current month', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreakCalendarGrid(
            calendar: _calendar(year: now.year, month: now.month),
            onPrevMonth: () {},
            onNextMonth: () {},
          ),
        ),
      ),
    );
    final nextBtn = tester.widget<IconButton>(
      find.byKey(const Key('streak-next-month')),
    );
    expect(nextBtn.onPressed, isNull);
  });

  testWidgets('prev-month arrow always enabled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreakCalendarGrid(
            calendar: _calendar(),
            onPrevMonth: () {},
            onNextMonth: () {},
          ),
        ),
      ),
    );
    final prevBtn = tester.widget<IconButton>(
      find.byKey(const Key('streak-prev-month')),
    );
    expect(prevBtn.onPressed, isNotNull);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd app && flutter test test/features/streak/widgets/streak_calendar_grid_test.dart`
Expected: FAIL — widget not defined.

- [ ] **Step 3: Write the widget**

```dart
// app/lib/features/streak/widgets/streak_calendar_grid.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/day_status.dart';
import '../models/streak_calendar.dart';

class StreakCalendarGrid extends StatelessWidget {
  const StreakCalendarGrid({
    super.key,
    required this.calendar,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  final StreakCalendar calendar;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentOrFuture = calendar.year > now.year ||
        (calendar.year == now.year && calendar.month >= now.month);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MonthNav(
          year: calendar.year,
          month: calendar.month,
          onPrev: onPrevMonth,
          onNext: isCurrentOrFuture ? null : onNextMonth,
        ),
        const SizedBox(height: 8),
        const _WeekHeader(),
        const SizedBox(height: 4),
        _Grid(calendar: calendar),
      ],
    );
  }
}

class _MonthNav extends StatelessWidget {
  const _MonthNav({
    required this.year,
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  final int year;
  final int month;
  final VoidCallback onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          key: const Key('streak-prev-month'),
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left),
        ),
        SizedBox(
          width: 140,
          child: Text(
            '$year년 $month월',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          key: const Key('streak-next-month'),
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader();

  @override
  Widget build(BuildContext context) {
    const labels = ['일', '월', '화', '수', '목', '금', '토'];
    return Row(
      children: labels
          .map(
            (l) => Expanded(
              child: Center(
                child: Text(
                  l,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.calendar});

  final StreakCalendar calendar;

  @override
  Widget build(BuildContext context) {
    final byDay = {for (final d in calendar.days) d.date.day: d};
    final firstWeekday =
        DateTime(calendar.year, calendar.month, 1).weekday % 7; // Sun=0
    final today = DateTime.now();

    final cells = <Widget>[];
    for (var i = 0; i < firstWeekday; i++) {
      cells.add(const _EmptyCell());
    }
    for (var d = 1; d <= calendar.days.length; d++) {
      final entry = byDay[d];
      final dt = DateTime(calendar.year, calendar.month, d);
      final isToday = dt.year == today.year &&
          dt.month == today.month &&
          dt.day == today.day;
      cells.add(_DayCell(day: d, entry: entry, isToday: isToday));
    }
    while (cells.length < 42) {
      cells.add(const _EmptyCell());
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1,
      children: cells,
    );
  }
}

class _EmptyCell extends StatelessWidget {
  const _EmptyCell();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.entry, required this.isToday});

  final int day;
  final StreakDay? entry;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = entry?.status ?? DayStatus.future;
    final dim = status == DayStatus.future || status == DayStatus.beforeJoin;

    final container = Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: isToday
            ? Border.all(color: theme.colorScheme.primary, width: 2)
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: theme.textTheme.bodySmall?.copyWith(
              color: dim
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                  : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          _statusIcon(status),
        ],
      ),
    );
    return container;
  }

  Widget _statusIcon(DayStatus status) {
    switch (status) {
      case DayStatus.success:
        return SvgPicture.asset('assets/icons/fire.svg', width: 16, height: 16);
      case DayStatus.failure:
        return SvgPicture.asset('assets/icons/ice.svg', width: 16, height: 16);
      case DayStatus.todayPending:
      case DayStatus.future:
      case DayStatus.beforeJoin:
        return const SizedBox(width: 16, height: 16);
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd app && flutter test test/features/streak/widgets/streak_calendar_grid_test.dart`
Expected: PASS — 4 tests.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/streak/widgets/streak_calendar_grid.dart app/test/features/streak/widgets/streak_calendar_grid_test.dart
git commit -m "feat(app): StreakCalendarGrid 위젯 + 월 nav"
```

---

## Task 12: StreakScreen 풀스크린

**Files:**
- Create: `app/lib/features/streak/screens/streak_screen.dart`

- [ ] **Step 1: Write the screen**

```dart
// app/lib/features/streak/screens/streak_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/streak_calendar_provider.dart';
import '../widgets/streak_calendar_grid.dart';
import '../widgets/streak_header.dart';

class StreakScreen extends ConsumerStatefulWidget {
  const StreakScreen({super.key});

  @override
  ConsumerState<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends ConsumerState<StreakScreen> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  void _shift(int delta) {
    setState(() {
      var y = _year;
      var m = _month + delta;
      if (m > 12) {
        m = 1;
        y += 1;
      } else if (m < 1) {
        m = 12;
        y -= 1;
      }
      _year = y;
      _month = m;
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(streakCalendarProvider((year: _year, month: _month)));

    return Scaffold(
      appBar: AppBar(title: const Text('연속 기록')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오기 실패: $e')),
        data: (cal) => SingleChildScrollView(
          child: Column(
            children: [
              StreakHeader(streak: cal.streak),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: StreakCalendarGrid(
                  calendar: cal,
                  onPrevMonth: () => _shift(-1),
                  onNextMonth: () => _shift(1),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd app && dart analyze lib/features/streak/`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add app/lib/features/streak/screens/streak_screen.dart
git commit -m "feat(app): StreakScreen 풀스크린 페이지 + 월 nav state"
```

---

## Task 13: 라우트 등록 (`/streak`)

**Files:**
- Modify: `app/lib/app.dart`

- [ ] **Step 1: import + route 추가**

`app/lib/app.dart` 의 import 블록 끝 (`import 'features/room_decoration/screens/room_decorator_screen.dart';` 다음 줄) 에:

```dart
import 'features/streak/screens/streak_screen.dart';
```

`/friends/contact-search` 라우트 다음 (배열 닫기 `]` 직전) 에 추가:

```dart
    // 연속 기록 페이지
    GoRoute(
      path: '/streak',
      builder: (context, state) => const StreakScreen(),
    ),
```

- [ ] **Step 2: Verify analyze**

Run: `cd app && dart analyze lib/app.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add app/lib/app.dart
git commit -m "feat(app): /streak 라우트 등록"
```

---

## Task 14: StatusBar streak pill 탭 활성화 + 테스트

**Files:**
- Modify: `app/lib/features/status_bar/widgets/status_bar.dart`
- Modify: `app/test/features/status_bar/widgets/status_bar_test.dart`

- [ ] **Step 1: Write the failing tap test**

`app/test/features/status_bar/widgets/status_bar_test.dart` 의 `void main() { group('StatusBar', () {` 블록 안에 새 테스트 추가:

```dart
testWidgets('tapping streak pill pushes /streak route', (tester) async {
  const stats = UserStats(
    streak: 7,
    verifiedToday: true,
    activeChallenges: 3,
    completedChallenges: 2,
    gems: 120,
  );

  String? pushedRoute;
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: StatusBar()),
      ),
      GoRoute(
        path: '/streak',
        builder: (context, state) {
          pushedRoute = '/streak';
          return const Scaffold(body: Text('streak page'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [userStatsProvider.overrideWith((_) async => stats)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();

  // streak pill 의 텍스트 ('7') 탭
  await tester.tap(find.text('7'));
  await tester.pumpAndSettle();

  expect(pushedRoute, '/streak');
});
```

`go_router` import 가 파일 상단에 없으면 추가:
```dart
import 'package:go_router/go_router.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/status_bar/widgets/status_bar_test.dart -p chrome`
(또는 그냥 `flutter test test/features/status_bar/`)
Expected: FAIL — `pushedRoute` 가 null (탭이 navigation 을 트리거하지 않음).

- [ ] **Step 3: Edit StatusBar to wrap streak pill in InkWell**

`app/lib/features/status_bar/widgets/status_bar.dart`:

상단에 import 추가:
```dart
import 'package:go_router/go_router.dart';
```

기존 streak pill 부분 (`Semantics(label: '스트릭 …', child: _StatPill(…streak…))`) 을 다음으로 교체:

```dart
Material(
  color: Colors.transparent,
  borderRadius: BorderRadius.circular(14),
  child: InkWell(
    onTap: () => context.push('/streak'),
    borderRadius: BorderRadius.circular(14),
    child: Semantics(
      label: '스트릭 ${stats.streak}일, 오늘 인증 ${stats.verifiedToday ? "완료" : "미완료"}',
      excludeSemantics: true,
      button: true,
      child: _StatPill(
        color: const Color(0xFFFF6B35),
        opacity: pillOpacity,
        child: _StatItem(
          asset: streakAsset,
          value: '${stats.streak}',
        ),
      ),
    ),
  ),
),
```

다른 두 pill (활성챌린지·젬) 은 그대로 둔다.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/features/status_bar/widgets/status_bar_test.dart`
Expected: PASS — 새 테스트 + 기존 테스트 모두 통과.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/status_bar/widgets/status_bar.dart app/test/features/status_bar/widgets/status_bar_test.dart
git commit -m "feat(app): StatusBar streak pill 탭 → /streak 진입"
```

---

## Task 15: 전체 Flutter 테스트 + 분석

- [ ] **Step 1: Analyze**

Run: `cd app && dart analyze`
Expected: `No issues found!` (또는 무관한 기존 경고만)

- [ ] **Step 2: Run all Flutter tests**

Run: `cd app && flutter test`
Expected: 전체 통과. 추가된 테스트 8 개 (StreakHeader 2 + StreakCalendarGrid 4 + StatusBar 신규 1 + 기존 status_bar 테스트).

테스트 실패 시 STOP — 원인 분석 후 수정. 새 테스트가 깨지면 widget/provider, 기존 테스트가 깨지면 status_bar 변경이 다른 케이스를 망친 것이므로 InkWell 위치 재검토.

---

## Task 16: iOS Simulator Clean Install + 시각 검증

- [ ] **Step 1: Boot simulator + clean install**

Run:
```bash
DEVICE_ID=$(xcrun simctl list devices booted | grep "Booted" | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
[ -z "$DEVICE_ID" ] && { echo "시뮬레이터가 부팅되지 않음 — 수동 부팅 필요"; exit 1; }
BUNDLE_ID=$(grep -m1 "PRODUCT_BUNDLE_IDENTIFIER" app/ios/Runner.xcodeproj/project.pbxproj | sed -E 's/.*= ([^;]+);.*/\1/' | tr -d '"')
xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl uninstall "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
cd app && flutter clean && flutter pub get && flutter build ios --simulator && cd ..
xcrun simctl install "$DEVICE_ID" app/build/ios/iphonesimulator/Runner.app
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"
```
Expected: 빌드 성공 + 앱 실행.

빌드 실패 시 STOP, 마지막 200 줄 로그 캡처.

- [ ] **Step 2: 시각 검증 시나리오**

`haeda-ios-tap` 스킬을 사용하여 다음 시나리오 자동 인터랙션 + 단계별 스크린샷:

1. 로그인 → 내 방 진입 (스크린샷 1)
2. 상단 status bar 의 streak pill (불꽃 + 숫자) 탭
3. `/streak` 페이지 진입 — 큰 streak 숫자 + 4월 캘린더 렌더링 확인 (스크린샷 2)
4. 좌 화살표로 3월 이동 — 캘린더 갱신 확인 (스크린샷 3)
5. 우 화살표로 4월 (현재) 복귀 — 우 화살표 disabled 확인 (스크린샷 4)
6. 뒤로가기 → 내 방 복귀 (스크린샷 5)

스크린샷 저장 경로: `docs/reports/screenshots/2026-04-27-feature-streak-page-{NN}.png`

- [ ] **Step 3: 검증 항목 체크**

- [ ] streak 숫자가 큰 글씨로 상단 강조됨
- [ ] "일 연속" 라벨 노출
- [ ] 캘린더 6×7 그리드 렌더링
- [ ] 인증한 날에 🔥 (fire.svg)
- [ ] 빠뜨린 날에 ❄ (ice.svg, 파란색)
- [ ] 오늘 날짜에 굵은 테두리
- [ ] 미래 날짜는 흐리게
- [ ] 월 nav 좌우 화살표 동작
- [ ] 현재 월에서 우 화살표 비활성

실패 항목이 있으면 STOP — 디버그 후 해당 Task 로 되돌아감.

---

## Task 17: 작업 보고서 작성 + 최종 커밋

**Files:**
- Create: `docs/reports/2026-04-27-feature-streak-page.md`

- [ ] **Step 1: 보고서 작성**

`docs/reports/2026-04-27-feature-streak-page.md` 에 다음 섹션을 채운다:

- 헤더: Date / Worktree (수행) / Worktree (영향) / Role
- Request: "어플리케이션 위에 연속 기록, 돈을 누르면 관련 페이지가 나와야 해. 연속 기록부터 우선 구현해보자…"
- Root cause / Context: 상태바 pill 탭 인터랙션 부재 + 전역 캘린더 뷰 부재
- Actions: 백엔드 신규 엔드포인트 / 서비스 / schema, 프론트 streak 모듈 신규, status bar 탭 활성화. 커밋 해시 인라인 인용.
- Verification: pytest 결과 (X passed) / flutter test 결과 / iOS simulator 스크린샷 경로
- Follow-ups: 돈 (젬) pill 탭 페이지 — 후속 슬라이스. provider 캐싱 정책 (현재 매 진입 fetch).
- Related: `docs/superpowers/specs/2026-04-27-streak-page-design.md`, `docs/superpowers/plans/2026-04-27-streak-page.md`

- [ ] **Step 2: Commit + push (PR)**

`/commit` 스킬을 사용하여 보고서 + 모든 변경사항을 한 번에 commit + PR + auto-merge.

예상 PR 제목: `feat(app,server): 연속 기록 페이지 (/streak) 추가`

---

## Self-review notes

**Spec coverage check:**
- §3 화면 구조 → Task 10/11/12 (header + grid + screen)
- §3.1 셀 상태별 시각 → Task 11 `_DayCell._statusIcon` + dim/border 로직
- §4 백엔드 API → Task 1/2/3/4 (schema + service + router + tests)
- §4 INVALID_MONTH → Task 4 endpoint validation
- §5 프론트 구조 → Task 7 (asset) + 8/9/10/11/12/13/14
- §6 데이터 흐름 → Task 9 provider + Task 12 screen 의존
- §7 Edge cases → Task 2/3 의 5 개 테스트 케이스 (미참여 / 가입 후 / 같은 날 두 인증 / 미래 가입)
- §8 테스트 → Task 2/3/4 (백엔드) + Task 10/11/14 (프론트)
- §8.3 통합 검증 → Task 6 (백엔드) + Task 15/16 (프론트)
- §11 참고 → Task 4 의 import 가 user_stats_service 재사용

모든 spec 요구사항이 task 로 매핑됨. 누락 없음.

**Type consistency:**
- `DayStatus` enum 5 값 — 백엔드 schema (Task 1), 프론트 enum (Task 8), 그리드 switch (Task 11) 모두 동일.
- `firstJoinDate` (frontend) ↔ `first_join_date` (backend) — `@JsonKey(name: 'first_join_date')` 매핑 (Task 8) 으로 일치.
- `YearMonth` typedef (Task 9) ↔ provider key (Task 12 watch) 동일.
- IconButton key `streak-prev-month`/`streak-next-month` — Task 11 widget 과 Task 11 test 일치.

**Placeholder scan:** 검색 결과 — TBD/TODO/적절히/handle edge cases 없음. 모든 코드 블록은 실제 실행 가능한 코드.
