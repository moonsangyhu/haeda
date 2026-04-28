# Challenge Pill (가장 최근 챌린지) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** status bar 의 lightning pill 을 "가장 최근에 인증한 챌린지" 진입 + 식별용 이모지로 변환한다 (streak/gem pill 과 동일 패턴).

**Architecture:** Backend 에서 `Challenge.icon` (default `🎯`) 컬럼을 추가하고 `GET /me/challenges` 응답에 `icon` + `last_verified_at` (사용자 본인 verification 의 최신 created_at) 을 포함하며 `last_verified_at DESC NULLS LAST, start_date DESC` 로 정렬한다. Frontend 는 결과의 첫 항목을 `mostRecentChallengeProvider` 로 노출하고, status bar 의 lightning pill 을 분기 — 챌린지 있으면 `Text(challenge.icon)` + 탭 → `/challenges/{id}`, 없으면 fallback `lightning.svg` + 탭 → `/create`. 챌린지 생성 Step1 에는 이모지 TextField (`maxLength=2`) 를 추가하고 blank 시 `🎯` default.

**Tech Stack:** FastAPI, SQLAlchemy 2.0 async, Alembic, Pydantic v2, pytest / Flutter, Riverpod, GoRouter, freezed, json_serializable, flutter_test.

**Spec:** `docs/superpowers/specs/2026-04-28-challenge-pill-recent-design.md`

---

## File Structure

### 백엔드 (변경 / 신규)
- `server/alembic/versions/20260428_0001_023_add_challenge_icon.py` — **신규**: 컬럼 추가 + `🎯` backfill (server_default 가 자동 처리)
- `server/app/models/challenge.py` — `icon` 컬럼 매핑
- `server/app/schemas/challenge.py` — `ChallengeCreate.icon`, `ChallengeListItem.icon`/`last_verified_at`, `ChallengeCreateResponse.icon`, `ChallengeDetail.icon`
- `server/app/services/challenge_service.py` — `create_challenge` icon 저장 + 응답 / `get_my_challenges` last_verified_at subquery + 정렬 + icon 매핑
- `server/tests/conftest.py` — `challenge` fixture 호환 (icon default 자동, 별도 인자 추가 없음)
- `server/tests/test_challenge_create_join.py` — icon 케이스 추가
- `server/tests/test_me.py` — icon / last_verified_at / 정렬 케이스 추가

### 프론트엔드 (변경 / 신규)
- `app/lib/features/my_page/models/challenge_summary.dart` — `icon` + `lastVerifiedAt` 필드
- `app/lib/features/challenge_space/models/challenge_detail.dart` — `icon` 필드 (응답 호환만, 표시 follow-up)
- `app/lib/features/challenge_create/providers/challenge_create_provider.dart` — `ChallengeCreateRequest.icon` 필드
- `app/lib/features/challenge_create/models/challenge_create_response.dart` — `icon` 필드
- `app/lib/features/challenge_create/screens/challenge_create_step1_screen.dart` — 이모지 TextField + extra 전달
- `app/lib/features/challenge_create/screens/challenge_create_step2_screen.dart` — `step1Data['icon']` 을 `ChallengeCreateRequest` 로 forward
- `app/lib/features/status_bar/providers/most_recent_challenge_provider.dart` — **신규**: `myChallengesProvider` 의 derived selector
- `app/lib/features/status_bar/widgets/status_bar.dart` — `_ChallengePill` 분기 위젯 신설 (asset|emoji 분기 + InkWell)
- `app/test/features/status_bar/widgets/status_bar_test.dart` — 새 분기 테스트 + 기존 lightning ratio 테스트 갱신
- `app/test/features/challenge_create/screens/challenge_create_step1_screen_test.dart` — emoji 필드 테스트 (신규 파일)

### 문서
- `docs/api-contract.md` — `POST /challenges` body 에 `icon` / `GET /me/challenges` 응답에 `icon` + `last_verified_at` + 정렬 규약 / `GET /challenges/:id` 응답에 `icon`

---

## Pre-Flight (작업 시작 전 1회)

- [ ] **Step 0.1: 워크트리 sync**

```bash
cd /Users/yumunsang/haeda/.claude/worktrees/feature
git fetch origin main
git rebase origin/main
```

Expected: clean fast-forward. Conflict 시 `/resolve-conflict` 스킬.

- [ ] **Step 0.2: backend 컨테이너 + DB 동작 확인**

```bash
docker compose up -d backend
sleep 2
curl -fsS http://localhost:8000/health
docker compose exec backend uv run alembic current
```

Expected: `{"status":"ok"}` + `022 (head)`.

- [ ] **Step 0.3: 기존 backend 테스트 baseline**

```bash
cd server && .venv/bin/python -m pytest tests/test_me.py tests/test_challenge_create_join.py -v 2>&1 | tail -20
```

기록만 — 작업 후 비교용. (예: 5 + 9 = 14 passed)

- [ ] **Step 0.4: 기존 flutter 테스트 baseline**

```bash
cd app && flutter test test/features/status_bar/ 2>&1 | tail -10
```

기록 — `2026-04-27-feature-gems-page.md` Follow-ups 에 기재된 status_bar 사전 결함 5개 (emoji vs asset mismatch) 가 있을 것이다. 본 plan 의 Task 18 에서 일부 해소된다.

---

## Phase 1 — Backend: Migration + Model

### Task 1: Alembic migration 023 + Challenge.icon 컬럼

**Files:**
- Create: `server/alembic/versions/20260428_0001_023_add_challenge_icon.py`
- Modify: `server/app/models/challenge.py`
- Test: `server/tests/test_challenge_create_join.py` (RED via existing happy_path 후 icon assertion 추가는 Task 2 에서. 이 Task 는 schema-level RED → 마이그레이션 적용 GREEN)

- [ ] **Step 1.1: Migration 파일 생성 (RED 도입)**

Create `server/alembic/versions/20260428_0001_023_add_challenge_icon.py`:

```python
"""add challenge.icon column

Revision ID: 023
Revises: 022
Create Date: 2026-04-28 00:01:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "023"
down_revision: Union[str, None] = "022"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # NOT NULL + server_default 로 기존 row 자동 backfill ('🎯').
    op.add_column(
        "challenges",
        sa.Column(
            "icon",
            sa.String(length=8),
            nullable=False,
            server_default=sa.text("'🎯'"),
        ),
    )


def downgrade() -> None:
    op.drop_column("challenges", "icon")
```

- [ ] **Step 1.2: Challenge 모델에 icon 매핑 추가**

Modify `server/app/models/challenge.py:48` (after `day_cutoff_hour` 매핑, before `created_at`):

```python
    icon: Mapped[str] = mapped_column(
        String(8), nullable=False, server_default="🎯"
    )
```

- [ ] **Step 1.3: 마이그레이션 적용 (GREEN)**

```bash
docker compose exec backend uv run alembic upgrade head
docker compose exec backend uv run alembic current
```

Expected: `023 (head)`.

- [ ] **Step 1.4: 기존 row backfill 검증**

```bash
docker compose exec db psql -U haeda -d haeda -c "SELECT id, title, icon FROM challenges LIMIT 5;"
```

Expected: 모든 기존 row `icon = '🎯'`. (테스트 환경의 DB 가 비어 있다면 0 rows — 정상.)

- [ ] **Step 1.5: pytest 회귀 (전체 통과 유지)**

```bash
cd server && .venv/bin/python -m pytest tests/test_challenge_create_join.py tests/test_me.py -v 2>&1 | tail -10
```

Expected: 기존 모든 케이스 PASS (icon 컬럼이 server_default 로 자동 채워지므로 기존 코드 영향 없음).

- [ ] **Step 1.6: Commit**

```bash
git add server/alembic/versions/20260428_0001_023_add_challenge_icon.py server/app/models/challenge.py
git commit -m "feat(server): challenges.icon 컬럼 추가 + 023 마이그레이션 (default 🎯)"
```

---

## Phase 2 — Backend: POST /challenges accepts icon

### Task 2: ChallengeCreate body 에 icon 입력 + 응답에 포함

**Files:**
- Modify: `server/app/schemas/challenge.py:17-44` (`ChallengeCreate` + `ChallengeCreateResponse`)
- Modify: `server/app/services/challenge_service.py:202-303` (`create_challenge`)
- Test: `server/tests/test_challenge_create_join.py:16-53` (happy path 확장)

- [ ] **Step 2.1: 실패 테스트 작성 (RED)**

Add to `server/tests/test_challenge_create_join.py` (직접 happy_path 함수 안에 assertion 추가하지 말고 새 케이스로 추가):

```python
@pytest.mark.asyncio
async def test_create_challenge_with_icon(
    client: AsyncClient,
    user: User,
):
    resp = await client.post(
        "/api/v1/challenges",
        json={
            "title": "아침 운동",
            "category": "운동",
            "start_date": "2026-04-05",
            "end_date": "2026-05-04",
            "verification_frequency": {"type": "daily"},
            "icon": "🏃",
        },
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 201
    assert resp.json()["data"]["icon"] == "🏃"


@pytest.mark.asyncio
async def test_create_challenge_default_icon(
    client: AsyncClient,
    user: User,
):
    resp = await client.post(
        "/api/v1/challenges",
        json={
            "title": "독서",
            "category": "독서",
            "start_date": "2026-04-05",
            "end_date": "2026-05-04",
            "verification_frequency": {"type": "daily"},
        },
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 201
    assert resp.json()["data"]["icon"] == "🎯"
```

- [ ] **Step 2.2: 테스트 실행 — 실패 확인**

```bash
cd server && .venv/bin/python -m pytest tests/test_challenge_create_join.py::test_create_challenge_with_icon tests/test_challenge_create_join.py::test_create_challenge_default_icon -v 2>&1 | tail -15
```

Expected: 두 테스트 모두 KeyError 또는 AssertionError 로 FAIL ("icon" 응답에 없음).

- [ ] **Step 2.3: ChallengeCreate / ChallengeCreateResponse 에 icon 필드 추가**

Modify `server/app/schemas/challenge.py:17-26`:

```python
class ChallengeCreate(BaseModel):
    title: str
    description: str | None = None
    category: str
    start_date: date
    end_date: date
    verification_frequency: dict
    photo_required: bool = False
    day_cutoff_hour: int = 0
    icon: str = Field(default="🎯", max_length=8)
```

`Field` import 추가 — 파일 상단 `from pydantic import BaseModel, Field` (이미 있음).

Modify `server/app/schemas/challenge.py:28-44` (`ChallengeCreateResponse`) — `created_at` 위에 추가:

```python
class ChallengeCreateResponse(BaseModel):
    id: uuid.UUID
    title: str
    description: str | None
    category: str
    start_date: date
    end_date: date
    verification_frequency: dict
    photo_required: bool
    day_cutoff_hour: int
    invite_code: str
    status: str
    creator: UserBrief
    member_count: int
    icon: str
    created_at: datetime

    model_config = {"from_attributes": True}
```

- [ ] **Step 2.4: create_challenge service 에서 icon 저장 + 응답**

Modify `server/app/services/challenge_service.py:258-271` — Challenge 생성자 호출에 `icon=data.icon` 추가:

```python
    challenge = Challenge(
        creator_id=user_id,
        title=data.title,
        description=data.description,
        category=data.category,
        start_date=data.start_date,
        end_date=data.end_date,
        verification_frequency=data.verification_frequency,
        photo_required=data.photo_required,
        day_cutoff_hour=data.day_cutoff_hour,
        invite_code=code,
        status="active",
        icon=data.icon,
    )
```

Modify `server/app/services/challenge_service.py:283-303` — return 에 `icon=challenge.icon` 추가:

```python
    return ChallengeCreateResponse(
        id=challenge.id,
        title=challenge.title,
        description=challenge.description,
        category=challenge.category,
        start_date=challenge.start_date,
        end_date=challenge.end_date,
        verification_frequency=challenge.verification_frequency,
        photo_required=challenge.photo_required,
        day_cutoff_hour=challenge.day_cutoff_hour,
        invite_code=challenge.invite_code,
        status=challenge.status,
        creator=UserBrief(
            id=creator.id,
            nickname=creator.nickname,
            discriminator=creator.discriminator,
            profile_image_url=creator.profile_image_url,
        ),
        member_count=1,
        icon=challenge.icon,
        created_at=challenge.created_at,
    )
```

- [ ] **Step 2.5: 테스트 GREEN 확인**

```bash
cd server && .venv/bin/python -m pytest tests/test_challenge_create_join.py -v 2>&1 | tail -15
```

Expected: 모든 (기존 + 신규 2) 케이스 PASS.

- [ ] **Step 2.6: Commit**

```bash
git add server/app/schemas/challenge.py server/app/services/challenge_service.py server/tests/test_challenge_create_join.py
git commit -m "feat(server): POST /challenges body 에 icon 수용 + 응답 포함"
```

---

## Phase 3 — Backend: GET /me/challenges 에 icon + last_verified_at + 정렬

### Task 3: ChallengeListItem 에 icon 추가

**Files:**
- Modify: `server/app/schemas/challenge.py:52-64` (ChallengeListItem)
- Modify: `server/app/services/challenge_service.py:124-136` (items 조립)
- Test: `server/tests/test_me.py`

- [ ] **Step 3.1: 실패 테스트 작성 (RED)**

Add to `server/tests/test_me.py`:

```python
@pytest.mark.asyncio
async def test_get_my_challenges_includes_icon(
    client: AsyncClient, user: User, challenge: Challenge, membership: ChallengeMember
):
    resp = await client.get(
        "/api/v1/me/challenges",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 200
    item = resp.json()["data"]["challenges"][0]
    # fixture 의 challenge 는 icon 미지정 → server_default '🎯'
    assert item["icon"] == "🎯"
```

- [ ] **Step 3.2: 테스트 실행 — 실패 확인**

```bash
cd server && .venv/bin/python -m pytest tests/test_me.py::test_get_my_challenges_includes_icon -v 2>&1 | tail -10
```

Expected: KeyError / AssertionError ("icon" 응답에 없음).

- [ ] **Step 3.3: ChallengeListItem 에 icon 추가**

Modify `server/app/schemas/challenge.py:52-64`:

```python
class ChallengeListItem(BaseModel):
    id: uuid.UUID
    title: str
    category: str
    start_date: date
    end_date: date
    status: str
    member_count: int
    achievement_rate: float
    badge: str | None
    today_verified: bool
    icon: str
    last_verified_at: datetime | None

    model_config = {"from_attributes": True}
```

(`last_verified_at` 도 같이 추가 — Task 4 에서 채울 예정. 이번 Task 에서는 None 으로 채워둔다.)

- [ ] **Step 3.4: get_my_challenges 에서 icon + last_verified_at=None 매핑**

Modify `server/app/services/challenge_service.py:123-137` — `ChallengeListItem(...)` 인자에 두 필드 추가:

```python
        items.append(
            ChallengeListItem(
                id=challenge.id,
                title=challenge.title,
                category=challenge.category,
                start_date=challenge.start_date,
                end_date=challenge.end_date,
                status=challenge.status,
                member_count=member_count_map.get(challenge.id, 0),
                achievement_rate=achievement_rate,
                badge=membership.badge,
                today_verified=challenge.id in today_verified_set,
                icon=challenge.icon,
                last_verified_at=None,  # populated in next task
            )
        )
```

- [ ] **Step 3.5: 테스트 GREEN 확인**

```bash
cd server && .venv/bin/python -m pytest tests/test_me.py -v 2>&1 | tail -15
```

Expected: 신규 + 기존 모든 테스트 PASS.

- [ ] **Step 3.6: Commit**

```bash
git add server/app/schemas/challenge.py server/app/services/challenge_service.py server/tests/test_me.py
git commit -m "feat(server): GET /me/challenges 응답에 icon 포함"
```

---

### Task 4: last_verified_at 계산 + 정렬

**Files:**
- Modify: `server/app/services/challenge_service.py:55-137` (get_my_challenges)
- Test: `server/tests/test_me.py`

- [ ] **Step 4.1: 실패 테스트 (last_verified_at 단일값) 작성**

Add to `server/tests/test_me.py`:

```python
@pytest.mark.asyncio
async def test_get_my_challenges_last_verified_at_null_when_no_verification(
    client: AsyncClient, user: User, challenge: Challenge, membership: ChallengeMember
):
    resp = await client.get(
        "/api/v1/me/challenges",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    item = resp.json()["data"]["challenges"][0]
    assert item["last_verified_at"] is None


@pytest.mark.asyncio
async def test_get_my_challenges_last_verified_at_with_verification(
    client: AsyncClient,
    db_session: AsyncSession,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    v = Verification(
        challenge_id=challenge.id,
        user_id=user.id,
        date=date(2026, 4, 10),
        photo_urls=None,
        diary_text="day 1",
    )
    db_session.add(v)
    await db_session.commit()

    resp = await client.get(
        "/api/v1/me/challenges",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    item = resp.json()["data"]["challenges"][0]
    assert item["last_verified_at"] is not None
    # ISO 8601 형식 (datetime → JSON 직렬화)
    assert "T" in item["last_verified_at"]
```

- [ ] **Step 4.2: 정렬 테스트 작성**

Add to `server/tests/test_me.py`:

```python
@pytest.mark.asyncio
async def test_get_my_challenges_sorted_by_last_verified_at(
    client: AsyncClient,
    db_session: AsyncSession,
    user: User,
):
    """3개 챌린지: A (verified 어제), B (verified 오늘), C (no verif)
    응답 순서: B, A, C (last_verified_at DESC NULLS LAST).
    """
    from datetime import timedelta
    chals = []
    for i, title in enumerate(["A", "B", "C"]):
        c = Challenge(
            creator_id=user.id,
            title=title,
            category="test",
            start_date=date(2026, 4, 1) - timedelta(days=i),
            end_date=date(2026, 5, 1),
            verification_frequency={"type": "daily"},
            invite_code=f"TEST{title}001"[:8],
            status="active",
        )
        db_session.add(c)
        await db_session.flush()
        m = ChallengeMember(challenge_id=c.id, user_id=user.id)
        db_session.add(m)
        chals.append(c)

    # A 어제 인증, B 오늘 인증, C 인증 없음
    today = date(2026, 4, 28)
    yesterday = date(2026, 4, 27)
    db_session.add(
        Verification(
            challenge_id=chals[0].id,
            user_id=user.id,
            date=yesterday,
            photo_urls=None,
            diary_text="A",
        )
    )
    db_session.add(
        Verification(
            challenge_id=chals[1].id,
            user_id=user.id,
            date=today,
            photo_urls=None,
            diary_text="B",
        )
    )
    await db_session.commit()

    resp = await client.get(
        "/api/v1/me/challenges",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    titles = [c["title"] for c in resp.json()["data"]["challenges"]]
    # B 가장 최근 인증, A 그 다음, C null 은 가장 뒤
    assert titles == ["B", "A", "C"]
```

- [ ] **Step 4.3: 테스트 실행 — 실패 확인**

```bash
cd server && .venv/bin/python -m pytest tests/test_me.py::test_get_my_challenges_last_verified_at_null_when_no_verification tests/test_me.py::test_get_my_challenges_last_verified_at_with_verification tests/test_me.py::test_get_my_challenges_sorted_by_last_verified_at -v 2>&1 | tail -20
```

Expected: 3개 모두 FAIL — `last_verified_at` 항상 null + 순서가 임의.

- [ ] **Step 4.4: get_my_challenges 에 subquery + ORDER BY 추가 (GREEN)**

Modify `server/app/services/challenge_service.py:55-137` (전체 함수 교체):

```python
async def get_my_challenges(
    db: AsyncSession,
    user_id: uuid.UUID,
    status_filter: str | None,
) -> list[ChallengeListItem]:
    # 사용자 본인의 챌린지별 마지막 인증 시각 subquery
    last_verif_subq = (
        select(
            Verification.challenge_id.label("challenge_id"),
            func.max(Verification.created_at).label("last_verified_at"),
        )
        .where(Verification.user_id == user_id)
        .group_by(Verification.challenge_id)
        .subquery()
    )

    stmt = (
        select(ChallengeMember, Challenge, last_verif_subq.c.last_verified_at)
        .join(Challenge, ChallengeMember.challenge_id == Challenge.id)
        .outerjoin(
            last_verif_subq,
            last_verif_subq.c.challenge_id == Challenge.id,
        )
        .where(ChallengeMember.user_id == user_id)
        .order_by(
            last_verif_subq.c.last_verified_at.desc().nullslast(),
            Challenge.start_date.desc(),
        )
    )
    if status_filter:
        stmt = stmt.where(Challenge.status == status_filter)

    result = await db.execute(stmt)
    rows = result.all()

    if not rows:
        return []

    challenge_ids = [row.Challenge.id for row in rows]

    member_count_stmt = (
        select(ChallengeMember.challenge_id, func.count(ChallengeMember.id).label("cnt"))
        .where(ChallengeMember.challenge_id.in_(challenge_ids))
        .group_by(ChallengeMember.challenge_id)
    )
    member_count_result = await db.execute(member_count_stmt)
    member_count_map: dict[uuid.UUID, int] = {
        row.challenge_id: row.cnt for row in member_count_result
    }

    verification_count_stmt = (
        select(Verification.challenge_id, func.count(Verification.id).label("cnt"))
        .where(
            Verification.user_id == user_id,
            Verification.challenge_id.in_(challenge_ids),
        )
        .group_by(Verification.challenge_id)
    )
    verification_count_result = await db.execute(verification_count_stmt)
    verification_count_map: dict[uuid.UUID, int] = {
        row.challenge_id: row.cnt for row in verification_count_result
    }

    today = date.today()
    today_verif_stmt = select(Verification.challenge_id).where(
        Verification.user_id == user_id,
        Verification.date == today,
        Verification.challenge_id.in_(challenge_ids),
    )
    today_verif_result = await db.execute(today_verif_stmt)
    today_verified_set: set[uuid.UUID] = {row[0] for row in today_verif_result.all()}

    items: list[ChallengeListItem] = []
    for row in rows:
        challenge = row.Challenge
        membership = row.ChallengeMember
        last_verified_at = row.last_verified_at
        verified_count = verification_count_map.get(challenge.id, 0)
        achievement_rate = _compute_achievement_rate(
            verified_count,
            challenge.start_date,
            challenge.end_date,
            challenge.verification_frequency,
        )
        items.append(
            ChallengeListItem(
                id=challenge.id,
                title=challenge.title,
                category=challenge.category,
                start_date=challenge.start_date,
                end_date=challenge.end_date,
                status=challenge.status,
                member_count=member_count_map.get(challenge.id, 0),
                achievement_rate=achievement_rate,
                badge=membership.badge,
                today_verified=challenge.id in today_verified_set,
                icon=challenge.icon,
                last_verified_at=last_verified_at,
            )
        )
    return items
```

- [ ] **Step 4.5: 테스트 GREEN 확인**

```bash
cd server && .venv/bin/python -m pytest tests/test_me.py tests/test_challenges.py -v 2>&1 | tail -20
```

Expected: 신규 3 + 기존 모든 me/challenges 테스트 PASS.

- [ ] **Step 4.6: Verification router import 가 service 에 있는지 확인**

Check `server/app/services/challenge_service.py:1-28` — `from app.models.verification import Verification` 가 이미 있음 (확인용). 없으면 추가.

- [ ] **Step 4.7: Commit**

```bash
git add server/app/services/challenge_service.py server/tests/test_me.py
git commit -m "feat(server): GET /me/challenges 에 last_verified_at + 정렬 (DESC NULLS LAST)"
```

---

### Task 5: ChallengeDetail 에 icon 추가

**Files:**
- Modify: `server/app/schemas/challenge.py:67-85`
- Modify: `server/app/services/challenge_service.py:177-199` (get_challenge_detail return)
- Test: `server/tests/test_challenges.py` (이미 detail 테스트 존재 — icon 검증 추가)

- [ ] **Step 5.1: 실패 테스트 작성**

Add to `server/tests/test_challenges.py` (파일 끝 또는 적절한 group 안):

```python
@pytest.mark.asyncio
async def test_get_challenge_detail_includes_icon(
    client: AsyncClient,
    db_session: AsyncSession,
    user: User,
):
    c = Challenge(
        creator_id=user.id,
        title="아이콘 테스트",
        category="기타",
        start_date=date(2026, 4, 1),
        end_date=date(2026, 5, 1),
        verification_frequency={"type": "daily"},
        invite_code="ICONTST1",
        status="active",
        icon="📚",
    )
    db_session.add(c)
    await db_session.flush()
    db_session.add(ChallengeMember(challenge_id=c.id, user_id=user.id))
    await db_session.commit()

    resp = await client.get(
        f"/api/v1/challenges/{c.id}",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 200
    assert resp.json()["data"]["icon"] == "📚"
```

- [ ] **Step 5.2: 테스트 실행 — 실패 확인**

```bash
cd server && .venv/bin/python -m pytest tests/test_challenges.py::test_get_challenge_detail_includes_icon -v 2>&1 | tail -10
```

- [ ] **Step 5.3: ChallengeDetail 에 icon 추가**

Modify `server/app/schemas/challenge.py:67-85`:

```python
class ChallengeDetail(BaseModel):
    id: uuid.UUID
    title: str
    description: str | None
    category: str
    start_date: date
    end_date: date
    verification_frequency: dict
    photo_required: bool
    day_cutoff_hour: int
    invite_code: str
    status: str
    creator: UserBrief
    member_count: int
    is_member: bool
    is_creator: bool
    icon: str
    created_at: datetime

    model_config = {"from_attributes": True}
```

- [ ] **Step 5.4: get_challenge_detail return 에 icon 추가**

Modify `server/app/services/challenge_service.py:177-199` — `ChallengeDetail(...)` 호출에 `icon=challenge.icon` 추가:

```python
    return ChallengeDetail(
        id=challenge.id,
        title=challenge.title,
        description=challenge.description,
        category=challenge.category,
        start_date=challenge.start_date,
        end_date=challenge.end_date,
        verification_frequency=challenge.verification_frequency,
        photo_required=challenge.photo_required,
        day_cutoff_hour=challenge.day_cutoff_hour,
        invite_code=challenge.invite_code,
        status=challenge.status,
        creator=UserBrief(
            id=creator.id,
            nickname=creator.nickname,
            discriminator=creator.discriminator,
            profile_image_url=creator.profile_image_url,
        ),
        member_count=member_count,
        is_member=is_member,
        is_creator=(challenge.creator_id == user_id),
        icon=challenge.icon,
        created_at=challenge.created_at,
    )
```

- [ ] **Step 5.5: 테스트 GREEN 확인**

```bash
cd server && .venv/bin/python -m pytest tests/test_challenges.py -v 2>&1 | tail -15
```

Expected: 신규 + 기존 모든 detail 테스트 PASS.

- [ ] **Step 5.6: Commit**

```bash
git add server/app/schemas/challenge.py server/app/services/challenge_service.py server/tests/test_challenges.py
git commit -m "feat(server): GET /challenges/:id 응답에 icon 포함"
```

---

## Phase 4 — Documentation

### Task 6: api-contract.md 업데이트

**Files:**
- Modify: `docs/api-contract.md`

- [ ] **Step 6.1: 챌린지 섹션 위치 찾기**

```bash
grep -n "POST /challenges\|GET /me/challenges\|GET /challenges/" docs/api-contract.md | head -10
```

기록 — 해당 섹션 라인 번호.

- [ ] **Step 6.2: POST /challenges body 에 icon 추가**

POST /challenges body 표/JSON 예시 안에 다음 라인 추가 (description 라인 근처, photo_required 위):

```
| icon | string | optional | 챌린지 식별 이모지 1글자. 미지정 시 기본 "🎯". maxLength 8 byte. |
```

JSON 예시에:

```json
"icon": "🏃"
```

응답 data 안에도 `"icon": "🎯"` 라인 추가.

- [ ] **Step 6.3: GET /me/challenges 응답에 icon + last_verified_at + 정렬 규약 추가**

응답 data.challenges[*] 표에:

```
| icon | string | required | 챌린지 식별 이모지 (default "🎯"). |
| last_verified_at | string \| null | required | 사용자 본인의 마지막 인증 created_at (ISO 8601). 인증 없으면 null. |
```

응답 JSON 예시에:

```json
"icon": "🏃",
"last_verified_at": "2026-04-28T10:30:00+09:00"
```

정렬 규약 섹션 추가 (응답 표 직후):

```
**정렬 규약**: `last_verified_at DESC NULLS LAST, start_date DESC`. 사용자가 가장 최근에 인증한 챌린지가 첫 번째.
```

- [ ] **Step 6.4: GET /challenges/:id 응답에 icon 추가**

응답 data 표/JSON 예시에 icon 라인 추가:

```
| icon | string | required | 챌린지 식별 이모지 (default "🎯"). |
```

- [ ] **Step 6.5: Commit**

```bash
git add docs/api-contract.md
git commit -m "docs(api): challenge.icon 필드 + GET /me/challenges 정렬 규약 추가"
```

---

## Phase 5 — Frontend: Models

### Task 7: ChallengeSummary 에 icon + lastVerifiedAt

**Files:**
- Modify: `app/lib/features/my_page/models/challenge_summary.dart`
- Generated: `app/lib/features/my_page/models/challenge_summary.freezed.dart`, `.g.dart`

- [ ] **Step 7.1: ChallengeSummary 모델에 필드 추가**

Modify `app/lib/features/my_page/models/challenge_summary.dart` — 전체 교체:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'challenge_summary.freezed.dart';
part 'challenge_summary.g.dart';

/// GET /me/challenges 응답의 challenges 배열 아이템.
/// api-contract.md §3 My Page 기준.
@freezed
class ChallengeSummary with _$ChallengeSummary {
  const factory ChallengeSummary({
    required String id,
    required String title,
    required String category,
    @JsonKey(name: 'start_date') required String startDate,
    @JsonKey(name: 'end_date') required String endDate,
    required String status,
    @JsonKey(name: 'member_count') required int memberCount,
    @JsonKey(name: 'achievement_rate') required double achievementRate,
    String? badge,
    @JsonKey(name: 'today_verified') @Default(false) bool todayVerified,
    @Default('🎯') String icon,
    @JsonKey(name: 'last_verified_at') DateTime? lastVerifiedAt,
  }) = _ChallengeSummary;

  factory ChallengeSummary.fromJson(Map<String, dynamic> json) =>
      _$ChallengeSummaryFromJson(json);
}
```

- [ ] **Step 7.2: build_runner 실행**

```bash
cd app && dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -10
```

Expected: `Succeeded after Xs with N outputs`.

- [ ] **Step 7.3: 컴파일 검증**

```bash
cd app && dart analyze lib/features/my_page/ 2>&1 | tail -10
```

Expected: `No issues found!`.

- [ ] **Step 7.4: Commit**

```bash
git add app/lib/features/my_page/models/challenge_summary.dart app/lib/features/my_page/models/challenge_summary.freezed.dart app/lib/features/my_page/models/challenge_summary.g.dart
git commit -m "feat(app): ChallengeSummary 에 icon + lastVerifiedAt 필드"
```

---

### Task 8: ChallengeCreateRequest 에 icon, ChallengeCreateResponse 에 icon

**Files:**
- Modify: `app/lib/features/challenge_create/providers/challenge_create_provider.dart:8-40`
- Modify: `app/lib/features/challenge_create/models/challenge_create_response.dart`

- [ ] **Step 8.1: ChallengeCreateRequest 에 icon 필드 추가**

Modify `app/lib/features/challenge_create/providers/challenge_create_provider.dart:8-40`:

```dart
/// POST /challenges 요청 바디.
class ChallengeCreateRequest {
  final String title;
  final String? description;
  final String category;
  final String startDate;
  final String endDate;
  final Map<String, dynamic> verificationFrequency;
  final bool photoRequired;
  final int dayCutoffHour;
  final String icon;

  const ChallengeCreateRequest({
    required this.title,
    this.description,
    required this.category,
    required this.startDate,
    required this.endDate,
    required this.verificationFrequency,
    required this.photoRequired,
    this.dayCutoffHour = 0,
    this.icon = '🎯',
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        if (description != null && description!.isNotEmpty)
          'description': description,
        'category': category,
        'start_date': startDate,
        'end_date': endDate,
        'verification_frequency': verificationFrequency,
        'photo_required': photoRequired,
        'day_cutoff_hour': dayCutoffHour,
        'icon': icon,
      };
}
```

- [ ] **Step 8.2: ChallengeCreateResponse 에 icon 추가**

Modify `app/lib/features/challenge_create/models/challenge_create_response.dart` — `createdAt` 위에 추가:

```dart
@freezed
class ChallengeCreateResponse with _$ChallengeCreateResponse {
  const factory ChallengeCreateResponse({
    required String id,
    required String title,
    String? description,
    required String category,
    @JsonKey(name: 'start_date') required String startDate,
    @JsonKey(name: 'end_date') required String endDate,
    @JsonKey(name: 'verification_frequency')
    required Map<String, dynamic> verificationFrequency,
    @JsonKey(name: 'photo_required') required bool photoRequired,
    @JsonKey(name: 'invite_code') required String inviteCode,
    required String status,
    required ChallengeCreatorBrief creator,
    @JsonKey(name: 'member_count') required int memberCount,
    @Default('🎯') String icon,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _ChallengeCreateResponse;
  // ...
}
```

(나머지 부분 변경 없음.)

- [ ] **Step 8.3: build_runner 실행**

```bash
cd app && dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -10
```

- [ ] **Step 8.4: 컴파일 검증**

```bash
cd app && dart analyze lib/features/challenge_create/ 2>&1 | tail -10
```

Expected: `No issues found!`.

- [ ] **Step 8.5: Commit**

```bash
git add app/lib/features/challenge_create/
git commit -m "feat(app): ChallengeCreateRequest/Response 에 icon 필드 (default 🎯)"
```

---

### Task 9: ChallengeDetail 모델에 icon 추가 (응답 호환만)

**Files:**
- Modify: `app/lib/features/challenge_space/models/challenge_detail.dart`

- [ ] **Step 9.1: 모델 확인**

```bash
cat app/lib/features/challenge_space/models/challenge_detail.dart
```

확인 후 `icon` 필드를 freezed factory 안에 추가 (createdAt 근처):

```dart
@Default('🎯') String icon,
```

- [ ] **Step 9.2: build_runner + analyze**

```bash
cd app && dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -5
cd app && dart analyze lib/features/challenge_space/ 2>&1 | tail -5
```

Expected: `No issues found!`.

- [ ] **Step 9.3: Commit**

```bash
git add app/lib/features/challenge_space/models/
git commit -m "feat(app): ChallengeDetail 에 icon 필드 (응답 호환)"
```

---

## Phase 6 — Frontend: mostRecentChallengeProvider

### Task 10: mostRecentChallengeProvider 신규

**Files:**
- Create: `app/lib/features/status_bar/providers/most_recent_challenge_provider.dart`
- Test: `app/test/features/status_bar/providers/most_recent_challenge_provider_test.dart` (신규)

- [ ] **Step 10.1: 실패 테스트 작성 (RED)**

Create `app/test/features/status_bar/providers/most_recent_challenge_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haeda/features/my_page/models/challenge_summary.dart';
import 'package:haeda/features/my_page/providers/my_challenges_provider.dart';
import 'package:haeda/features/status_bar/providers/most_recent_challenge_provider.dart';

ChallengeSummary _summary(String id, String icon) => ChallengeSummary(
      id: id,
      title: 'title-$id',
      category: 'cat',
      startDate: '2026-04-01',
      endDate: '2026-05-01',
      status: 'active',
      memberCount: 1,
      achievementRate: 0.0,
      icon: icon,
    );

void main() {
  group('mostRecentChallengeProvider', () {
    test('returns null when myChallenges is empty', () {
      final container = ProviderContainer(overrides: [
        myChallengesProvider.overrideWith((ref) async => const <ChallengeSummary>[]),
      ]);
      addTearDown(container.dispose);

      // resolve
      container.read(myChallengesProvider.future);
      expect(container.read(mostRecentChallengeProvider), isNull);
    });

    test('returns first item (server already sorted)', () async {
      final container = ProviderContainer(overrides: [
        myChallengesProvider.overrideWith((ref) async => [
              _summary('a', '🏃'),
              _summary('b', '📚'),
            ]),
      ]);
      addTearDown(container.dispose);

      await container.read(myChallengesProvider.future);
      final first = container.read(mostRecentChallengeProvider);
      expect(first?.id, 'a');
      expect(first?.icon, '🏃');
    });
  });
}
```

- [ ] **Step 10.2: 테스트 실행 — 실패 확인**

```bash
cd app && flutter test test/features/status_bar/providers/most_recent_challenge_provider_test.dart 2>&1 | tail -10
```

Expected: import 에러 (provider 파일 없음) 으로 FAIL.

- [ ] **Step 10.3: Provider 작성 (GREEN)**

Create `app/lib/features/status_bar/providers/most_recent_challenge_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../my_page/models/challenge_summary.dart';
import '../../my_page/providers/my_challenges_provider.dart';

/// 사용자가 가장 최근에 인증한 챌린지 (없으면 null).
///
/// 서버가 `last_verified_at DESC NULLS LAST, start_date DESC` 로 정렬해 주므로
/// `myChallengesProvider` 응답의 첫 항목을 그대로 반환한다.
final mostRecentChallengeProvider = Provider<ChallengeSummary?>((ref) {
  final list = ref.watch(myChallengesProvider).valueOrNull;
  if (list == null || list.isEmpty) return null;
  return list.first;
});
```

- [ ] **Step 10.4: 테스트 GREEN 확인**

```bash
cd app && flutter test test/features/status_bar/providers/most_recent_challenge_provider_test.dart 2>&1 | tail -10
```

Expected: `All tests passed!` (2 케이스).

- [ ] **Step 10.5: Commit**

```bash
git add app/lib/features/status_bar/providers/most_recent_challenge_provider.dart app/test/features/status_bar/providers/most_recent_challenge_provider_test.dart
git commit -m "feat(app): mostRecentChallengeProvider — myChallenges[0] selector"
```

---

## Phase 7 — Frontend: Challenge Create Step1 Emoji Input

### Task 11: Step1 화면에 이모지 TextField 추가

**Files:**
- Modify: `app/lib/features/challenge_create/screens/challenge_create_step1_screen.dart`
- Test: `app/test/features/challenge_create/screens/challenge_create_step1_screen_test.dart` (신규)

- [ ] **Step 11.1: 실패 테스트 작성 (RED)**

Create `app/test/features/challenge_create/screens/challenge_create_step1_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:haeda/features/challenge_create/screens/challenge_create_step1_screen.dart';

void main() {
  group('ChallengeCreateStep1Screen — emoji input', () {
    testWidgets('blank emoji uses default 🎯', (tester) async {
      Map<String, dynamic>? capturedExtra;
      final router = GoRouter(
        initialLocation: '/create',
        routes: [
          GoRoute(
            path: '/create',
            builder: (_, __) => const ChallengeCreateStep1Screen(),
          ),
          GoRoute(
            path: '/create/step2',
            builder: (context, state) {
              capturedExtra = state.extra as Map<String, dynamic>?;
              return const Scaffold(body: Text('step2'));
            },
          ),
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('home')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('category_field')), '운동');
      await tester.enterText(find.byKey(const Key('title_field')), '아침 운동');
      // emoji_field 비워둠
      await tester.tap(find.byKey(const Key('next_button')));
      await tester.pumpAndSettle();

      expect(capturedExtra, isNotNull);
      expect(capturedExtra!['icon'], '🎯');
    });

    testWidgets('emoji input forwards as-is', (tester) async {
      Map<String, dynamic>? capturedExtra;
      final router = GoRouter(
        initialLocation: '/create',
        routes: [
          GoRoute(
            path: '/create',
            builder: (_, __) => const ChallengeCreateStep1Screen(),
          ),
          GoRoute(
            path: '/create/step2',
            builder: (context, state) {
              capturedExtra = state.extra as Map<String, dynamic>?;
              return const Scaffold(body: Text('step2'));
            },
          ),
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('home')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('category_field')), '운동');
      await tester.enterText(find.byKey(const Key('title_field')), '러닝');
      await tester.enterText(find.byKey(const Key('emoji_field')), '🏃');
      await tester.tap(find.byKey(const Key('next_button')));
      await tester.pumpAndSettle();

      expect(capturedExtra!['icon'], '🏃');
    });
  });
}
```

- [ ] **Step 11.2: 테스트 실행 — 실패 확인**

```bash
cd app && flutter test test/features/challenge_create/screens/challenge_create_step1_screen_test.dart 2>&1 | tail -10
```

Expected: FAIL — `Key('emoji_field')` 미존재 + `extra['icon']` 없음.

- [ ] **Step 11.3: Step1 화면에 emoji 필드 추가 (GREEN)**

Modify `app/lib/features/challenge_create/screens/challenge_create_step1_screen.dart`:

(1) state class 에 controller 추가 — `_descriptionController` 선언 직후:

```dart
  final _iconController = TextEditingController();
```

(2) `dispose()` 에 추가:

```dart
    _iconController.dispose();
```

(3) `_onNext()` 메서드 안 — `extra` 맵에 icon 추가:

```dart
  void _onNext() {
    if (_formKey.currentState!.validate()) {
      final iconText = _iconController.text.trim();
      context.go(
        '/create/step2',
        extra: {
          'category': _categoryController.text.trim(),
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'icon': iconText.isEmpty ? '🎯' : iconText,
        },
      );
    }
  }
```

(4) `build()` 메서드의 `ListView` children — `_FieldLabel('카테고리')` 위에 emoji 필드 섹션 추가:

```dart
            _FieldLabel('이모지 (선택)'),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('emoji_field'),
              controller: _iconController,
              maxLength: 2,
              decoration: const InputDecoration(
                hintText: '🎯',
                helperText: '챌린지를 한눈에 식별할 이모지 1글자 (미입력 시 기본 🎯)',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 20),
```

- [ ] **Step 11.4: 테스트 GREEN 확인**

```bash
cd app && flutter test test/features/challenge_create/screens/challenge_create_step1_screen_test.dart 2>&1 | tail -10
```

Expected: `All tests passed!` (2 케이스).

- [ ] **Step 11.5: Commit**

```bash
git add app/lib/features/challenge_create/screens/challenge_create_step1_screen.dart app/test/features/challenge_create/screens/challenge_create_step1_screen_test.dart
git commit -m "feat(app): 챌린지 만들기 Step1 에 이모지 TextField 추가 (default 🎯)"
```

---

### Task 12: Step2 가 step1Data['icon'] 을 ChallengeCreateRequest 로 forward

**Files:**
- Modify: `app/lib/features/challenge_create/screens/challenge_create_step2_screen.dart:85-94`

- [ ] **Step 12.1: Step2 의 ChallengeCreateRequest 생성에 icon 전달**

Modify `app/lib/features/challenge_create/screens/challenge_create_step2_screen.dart:85-94`:

```dart
    final request = ChallengeCreateRequest(
      title: widget.step1Data['title'] as String,
      description: widget.step1Data['description'] as String?,
      category: widget.step1Data['category'] as String,
      startDate: _dateFormatter.format(_startDate!),
      endDate: _dateFormatter.format(_endDate!),
      verificationFrequency: _buildFrequency(),
      photoRequired: _photoRequired,
      dayCutoffHour: _dayCutoffHour,
      icon: (widget.step1Data['icon'] as String?) ?? '🎯',
    );
```

- [ ] **Step 12.2: dart analyze 검증**

```bash
cd app && dart analyze lib/features/challenge_create/ 2>&1 | tail -5
```

Expected: `No issues found!`.

- [ ] **Step 12.3: Commit**

```bash
git add app/lib/features/challenge_create/screens/challenge_create_step2_screen.dart
git commit -m "feat(app): Step2 가 step1Data['icon'] 을 POST body 로 forward"
```

---

## Phase 8 — Frontend: StatusBar Refactor

### Task 13: StatusBar — _StatItem 을 asset|emoji 분기로 확장

**Files:**
- Modify: `app/lib/features/status_bar/widgets/status_bar.dart:136-167`

- [ ] **Step 13.1: _StatItem 시그니처 확장**

Modify `app/lib/features/status_bar/widgets/status_bar.dart:136-167`:

```dart
class _StatItem extends StatelessWidget {
  const _StatItem({
    this.asset,
    this.emoji,
    required this.value,
  }) : assert(asset != null || emoji != null,
            'asset 또는 emoji 중 하나는 반드시 지정');

  final String? asset;
  final String? emoji;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (emoji != null)
          Text(
            emoji!,
            style: const TextStyle(fontSize: 18),
          )
        else
          SvgPicture.asset(
            'assets/icons/$asset.svg',
            width: 20,
            height: 20,
          ),
        const SizedBox(width: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 13.2: dart analyze 검증**

```bash
cd app && dart analyze lib/features/status_bar/ 2>&1 | tail -5
```

Expected: `No issues found!`.

이 단계는 위젯 내부 분기 추가만이며 외부 호출자는 기존처럼 `asset:` 만 전달해도 동작 유지 (다른 두 pill 변경 없음).

- [ ] **Step 13.3: 회귀 테스트 (전체 status_bar)**

```bash
cd app && flutter test test/features/status_bar/ 2>&1 | tail -10
```

기록 — Task 18 직전까지 emoji-vs-asset 사전 결함 갯수 변동 없는지 모니터.

- [ ] **Step 13.4: Commit**

```bash
git add app/lib/features/status_bar/widgets/status_bar.dart
git commit -m "refactor(app): StatusBar _StatItem 을 asset|emoji 분기로 확장"
```

---

### Task 14: StatusBar — _ChallengePill 분기 위젯 도입

**Files:**
- Modify: `app/lib/features/status_bar/widgets/status_bar.dart`
- Test: `app/test/features/status_bar/widgets/status_bar_test.dart`

- [ ] **Step 14.1: 실패 테스트 작성 (RED) — has-challenge 케이스**

Add to `app/test/features/status_bar/widgets/status_bar_test.dart` (test group 안 적절한 위치):

```dart
import 'package:haeda/features/my_page/models/challenge_summary.dart';
import 'package:haeda/features/my_page/providers/my_challenges_provider.dart';

// 위 import 두 줄을 파일 상단 import 영역에 추가.

ChallengeSummary _challengeSummary({
  required String id,
  required String icon,
  required String title,
}) =>
    ChallengeSummary(
      id: id,
      title: title,
      category: 'cat',
      startDate: '2026-04-01',
      endDate: '2026-05-01',
      status: 'active',
      memberCount: 1,
      achievementRate: 0.0,
      icon: icon,
    );

testWidgets('challenge pill — most recent emoji + tap → /challenges/:id', (tester) async {
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
        path: '/challenges/:id',
        builder: (context, state) {
          pushedRoute = '/challenges/${state.pathParameters['id']}';
          return const Scaffold(body: Text('challenge space'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userStatsProvider.overrideWith((_) async => stats),
        myChallengesProvider.overrideWith((ref) async => [
              _challengeSummary(id: 'abc-123', icon: '🏃', title: '아침 운동'),
            ]),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('🏃'), findsOneWidget);
  // active count = 3
  expect(find.text('3'), findsOneWidget);

  await tester.tap(find.text('🏃'));
  await tester.pumpAndSettle();

  expect(pushedRoute, '/challenges/abc-123');
});
```

- [ ] **Step 14.2: 실패 테스트 작성 (RED) — empty 케이스**

Add (같은 group 안):

```dart
testWidgets('challenge pill — no challenges → lightning + tap → /create', (tester) async {
  const stats = UserStats(
    streak: 0,
    verifiedToday: false,
    activeChallenges: 0,
    completedChallenges: 0,
    gems: 0,
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
        path: '/create',
        builder: (context, state) {
          pushedRoute = '/create';
          return const Scaffold(body: Text('create'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userStatsProvider.overrideWith((_) async => stats),
        myChallengesProvider.overrideWith((_) async => const <ChallengeSummary>[]),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  // active = 0 이라 fallback lightning + 텍스트 0
  expect(find.text('0'), findsWidgets);

  // lightning SVG asset 존재 확인 — 위젯 트리에 SvgPicture(assetName: 'lightning.svg')
  final svgs = tester.widgetList(find.byType(SvgPicture));
  expect(svgs, isNotEmpty);

  // tap challenge pill — 위치는 가운데 pill. activeChallenges=0 텍스트가 challenge pill 임
  // (gem pill 텍스트는 '0' 일 수도 있으니 명시적으로 lightning 영역 탭하기 위해
  //  pill 의 InkWell 을 byKey 로 찾는다.)
  await tester.tap(find.byKey(const Key('challenge_pill')));
  await tester.pumpAndSettle();

  expect(pushedRoute, '/create');
});
```

- [ ] **Step 14.3: 테스트 실행 — 실패 확인**

```bash
cd app && flutter test test/features/status_bar/widgets/status_bar_test.dart 2>&1 | tail -20
```

Expected: 2 신규 + 1 기존 (`displays challenges as active/completed ratio`) FAIL.

- [ ] **Step 14.4: StatusBar 에 _ChallengePill 도입 (GREEN)**

Modify `app/lib/features/status_bar/widgets/status_bar.dart`:

(1) imports 영역에 추가:

```dart
import '../../my_page/models/challenge_summary.dart';
import '../providers/most_recent_challenge_provider.dart';
```

(2) `_StatusBarContent` 의 클래스 선언을 `extends ConsumerWidget` 로 변경하고, `Row` children 중간 (lightning pill 위치) 을 `_ChallengePill` 로 교체:

기존 (line 23-110):

```dart
class _StatusBarContent extends StatelessWidget {
  const _StatusBarContent({required this.stats});

  final UserStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ...
```

새:

```dart
class _StatusBarContent extends ConsumerWidget {
  const _StatusBarContent({required this.stats});

  final UserStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final streakAsset = stats.verifiedToday ? 'fire' : 'sleep';
    final isDark = theme.brightness == Brightness.dark;
    final pillOpacity = isDark ? 0.10 : 0.15;
    final mostRecent = ref.watch(mostRecentChallengeProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: theme.scaffoldBackgroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Streak pill (변경 없음)
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => context.push('/streak'),
                  borderRadius: BorderRadius.circular(14),
                  child: Semantics(
                    label:
                        '스트릭 ${stats.streak}일, 오늘 인증 ${stats.verifiedToday ? "완료" : "미완료"}',
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
              _ChallengePill(
                stats: stats,
                mostRecent: mostRecent,
                pillOpacity: pillOpacity,
              ),
              // Gem pill (변경 없음)
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => context.push('/gems'),
                  borderRadius: BorderRadius.circular(14),
                  child: Semantics(
                    label: '젬 ${stats.gems}개',
                    excludeSemantics: true,
                    button: true,
                    child: _StatPill(
                      color: const Color(0xFF4FC3F7),
                      opacity: pillOpacity,
                      child: _StatItem(
                        asset: 'gem',
                        value: '${stats.gems}',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: theme.colorScheme.outline.withValues(alpha: 0.4),
        ),
      ],
    );
  }
}

class _ChallengePill extends StatelessWidget {
  const _ChallengePill({
    required this.stats,
    required this.mostRecent,
    required this.pillOpacity,
  });

  final UserStats stats;
  final ChallengeSummary? mostRecent;
  final double pillOpacity;

  @override
  Widget build(BuildContext context) {
    final hasChallenge = mostRecent != null;
    final tapTarget = hasChallenge
        ? '/challenges/${mostRecent!.id}'
        : '/create';
    final semanticsLabel = hasChallenge
        ? '챌린지 ${mostRecent!.title}, 진행 중 ${stats.activeChallenges}개'
        : '챌린지 없음, 만들기';

    final item = hasChallenge
        ? _StatItem(emoji: mostRecent!.icon, value: '${stats.activeChallenges}')
        : _StatItem(asset: 'lightning', value: '${stats.activeChallenges}');

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const Key('challenge_pill'),
        onTap: () => context.push(tapTarget),
        borderRadius: BorderRadius.circular(14),
        child: Semantics(
          label: semanticsLabel,
          excludeSemantics: true,
          button: true,
          child: _StatPill(
            color: const Color(0xFFFFB800),
            opacity: pillOpacity,
            child: item,
          ),
        ),
      ),
    );
  }
}
```

(3) 기존 `_StatItem` 의 `asset` 필수 인자가 모든 호출자에서 명시적으로 키워드로 전달되는지 확인 — 위 변경에서 streak/gem 은 `asset:` 키워드 사용. OK.

- [ ] **Step 14.5: 테스트 GREEN 확인 (신규 2개)**

```bash
cd app && flutter test test/features/status_bar/widgets/status_bar_test.dart --plain-name "challenge pill" 2>&1 | tail -10
```

Expected: 2 신규 케이스 PASS.

- [ ] **Step 14.6: dart analyze 검증**

```bash
cd app && dart analyze lib/features/status_bar/ 2>&1 | tail -5
```

Expected: `No issues found!`.

- [ ] **Step 14.7: Commit**

```bash
git add app/lib/features/status_bar/widgets/status_bar.dart app/test/features/status_bar/widgets/status_bar_test.dart
git commit -m "feat(app): StatusBar _ChallengePill — 가장 최근 챌린지 이모지 + tap 분기"
```

---

### Task 15: 기존 ratio 테스트 갱신 (사전 결함 해소 일부)

**Files:**
- Modify: `app/test/features/status_bar/widgets/status_bar_test.dart`

기존 `displays challenges as active/completed ratio` 테스트는 `find.text('4/6')` 와 `find.text('🏃')` 를 함께 기대한다. 새 디자인에서는 active 만 표시 (`'4'`) 하고 lightning fallback 시에만 SVG. 이 테스트를 새 동작에 맞게 재작성한다.

- [ ] **Step 15.1: 기존 테스트 케이스 교체**

Modify `app/test/features/status_bar/widgets/status_bar_test.dart` — `displays challenges as active/completed ratio` 테스트 전체를 다음으로 교체:

```dart
testWidgets('displays active challenge count when no most-recent', (tester) async {
  const stats = UserStats(
    streak: 5,
    verifiedToday: true,
    activeChallenges: 4,
    completedChallenges: 6,
    gems: 200,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userStatsProvider.overrideWith((_) async => stats),
        myChallengesProvider.overrideWith((_) async => const <ChallengeSummary>[]),
      ],
      child: const MaterialApp(
        home: Scaffold(body: StatusBar()),
      ),
    ),
  );
  await tester.pump();

  // 새 디자인: ratio 가 아니라 active 만
  expect(find.text('4'), findsWidgets);
  // myChallenges 비어있으니 lightning 표시
  final svgs = tester.widgetList(find.byType(SvgPicture));
  expect(svgs, isNotEmpty);
});
```

- [ ] **Step 15.2: 전체 status_bar 테스트 실행**

```bash
cd app && flutter test test/features/status_bar/ 2>&1 | tail -15
```

Expected: 신규 4개 + 기존 케이스 (loading/error/streak/gem tap 등) 모두 PASS. 사전 결함 (emoji vs asset 5개) 중 일부 해소될 수 있음 — 결과 기록.

- [ ] **Step 15.3: Commit**

```bash
git add app/test/features/status_bar/widgets/status_bar_test.dart
git commit -m "test(app): StatusBar ratio 테스트를 새 디자인 (active count + fallback) 에 맞춰 갱신"
```

---

## Phase 9 — Verification

### Task 16: 백엔드 통합 검증

- [ ] **Step 16.1: 전체 pytest 실행**

```bash
cd server && .venv/bin/python -m pytest -v 2>&1 | tail -30
```

Expected: 신규 추가된 테스트 (challenge_create with_icon, default_icon / me/challenges icon, last_verified_at null/with_verification, sorted / challenges detail icon) 모두 PASS. 기존 테스트 회귀 없음.

수치 기록 — 예: `XXX passed in YY.ZZs`. 사전 결함 (TestSignature 6 등) 그대로.

- [ ] **Step 16.2: docker compose rebuild + health check**

```bash
docker compose up --build -d backend
sleep 3
curl -fsS http://localhost:8000/health
docker compose exec backend uv run alembic current
```

Expected: `{"status":"ok"}` + `023 (head)`.

- [ ] **Step 16.3: 변경 이력 commit (이미 모든 단계에서 commit 완료, 검증 자체는 코드 변경 없음. 다음 단계로.)**

검증 단계는 별도 commit 불필요.

---

### Task 17: 프론트엔드 통합 검증 + iOS simulator 클린 인스톨

- [ ] **Step 17.1: dart analyze 전체 + flutter test 전체**

```bash
cd app && dart analyze lib/ 2>&1 | tail -10
```

Expected: `No issues found!` (또는 본 작업과 무관한 사전 결함만).

```bash
cd app && flutter test 2>&1 | tail -20
```

수치 기록 — 신규 + 기존 PASS 합계 + 사전 결함 (이번 작업과 무관) 갯수.

- [ ] **Step 17.2: iOS simulator clean install (`.claude/rules/ios-simulator.md` 절차)**

```bash
DEVICE_ID=$(xcrun simctl list devices booted | grep "Booted" | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
echo "DEVICE_ID=$DEVICE_ID"
BUNDLE_ID=$(grep -m1 "PRODUCT_BUNDLE_IDENTIFIER" app/ios/Runner.xcodeproj/project.pbxproj | sed -E 's/.*= ([^;]+);.*/\1/' | tr -d '"')
echo "BUNDLE_ID=$BUNDLE_ID"

xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl uninstall "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true

cd app && flutter clean && flutter pub get && flutter build ios --simulator && cd ..

xcrun simctl install "$DEVICE_ID" app/build/ios/iphonesimulator/Runner.app
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"
```

Expected: simulator 에 앱 설치 + 실행. 앱 첫 화면 도달.

- [ ] **Step 17.3: 5단계 시각 검증 (`.claude/skills/haeda-ios-tap` 활용)**

각 단계에서 스크린샷 캡처 → `docs/reports/screenshots/2026-04-28-feature-challenge-pill-{NN}-{slug}.png`.

| # | 시나리오 | 스크린샷 파일명 | 통과 기준 |
|---|---------|---------------|---------|
| 1 | 앱 launch → my-page, status bar 의 lightning pill 위치에 fallback lightning + active 0 (또는 기존 챌린지 있으면 그 이모지) | `01-launch.png` | pill 렌더 |
| 2 | pill 탭 → /create 진입 (챌린지 없을 때) 또는 /challenges/{id} 진입 (있을 때) | `02-tap.png` | 라우팅 |
| 3 | (만약 신규 사용자였다면) 챌린지 만들기 — Step1 에 이모지 입력 (🏃) → Step2 → 생성 | `03-create-step1.png` | emoji 필드 표시 |
| 4 | 생성 완료 후 my-page 복귀 → status bar pill = `[🏃 1]` | `04-after-create.png` | 이모지 + active 개수 |
| 5 | pill 탭 → `/challenges/{id}` 진입 | `05-tap-pill.png` | 라우팅 |

각 스크린샷 캡처는 `xcrun simctl io <DEVICE_ID> screenshot ...` 또는 idb. 자세한 절차는 `.claude/skills/haeda-ios-tap/SKILL.md`.

- [ ] **Step 17.4: 최종 확인**

5/5 통과 확인. 실패 시 STOP, 사용자에게 로그 + 스크린샷 보고.

---

### Task 18: 작업 보고서 작성

**Files:**
- Create: `docs/reports/2026-04-28-feature-challenge-pill-recent.md`

- [ ] **Step 18.1: 보고서 작성**

`.claude/rules/worktree-task-report.md` 템플릿대로:
- 헤더 (Date, Worktree (수행/영향), Role)
- Request (사용자 원문 인용)
- Root cause / Context (왜 필요했는지)
- Actions (백엔드 / 프론트 / docs 각 commit hash + 변경 요약 표)
- Verification (pytest / flutter test / iOS simulator 5단계 결과 + 스크린샷 링크)
- Follow-ups (챌린지방 이모지 수정 / preset chip / sorting 보정 케이스)
- Related (spec, plan, related reports)

**Referenced Reports** 섹션 (regression-prevention.md 의무):
- `docs/reports/2026-04-27-feature-streak-page.md`
- `docs/reports/2026-04-27-feature-gems-page.md`
- 검색 키워드 기록: `status_bar`, `pill`, `lightning`, `challenge`, `emoji`

- [ ] **Step 18.2: 보고서 + 스크린샷 commit**

```bash
git add docs/reports/2026-04-28-feature-challenge-pill-recent.md docs/reports/screenshots/2026-04-28-feature-challenge-pill-*.png
git commit -m "docs(report): 챌린지 pill 가장 최근 챌린지 진입 + 이모지 작업 보고서"
```

- [ ] **Step 18.3: PR 생성 + 자동 머지**

`/commit` 스킬 호출 — 워크트리 브랜치 (`worktree-feature`) 의 모든 커밋을 main 으로 PR + auto-merge.

(자세한 절차는 `.claude/skills/commit/SKILL.md`. 직접 main push 금지.)

---

## Self-Review Checklist (Plan 작성자가 직접 확인)

**1. Spec coverage:**
- [x] Spec §1 결정 (last_verified_at) → Task 4
- [x] Spec §2 결정 (Challenge.icon) → Task 1, 2
- [x] Spec §3 결정 (empty fallback) → Task 14 step 14.2
- [x] Spec §4 결정 (이모지 + active 개수) → Task 14 _ChallengePill
- [x] Spec §5 결정 (Step1 TextField + 🎯 default) → Task 11
- [x] Spec §6 결정 (범위: 1+2+3a) → Tasks 1-15. 챌린지방 수정 (3b) Out of scope.
- [x] api-contract.md 명세 → Task 6
- [x] Migration backfill → Task 1
- [x] mostRecentChallengeProvider → Task 10
- [x] _ChallengePill 분리 → Task 14
- [x] _StatItem asset|emoji 분기 → Task 13
- [x] 시각 5단계 검증 → Task 17

**2. Placeholder scan:** 없음. 모든 step 에 실행 가능한 코드 / 명령어 / Expected 결과 명시.

**3. Type consistency:**
- `Challenge.icon` (서버) ↔ `ChallengeSummary.icon` / `ChallengeDetail.icon` / `ChallengeCreateResponse.icon` (앱) 모두 `String`, default `'🎯'`.
- `last_verified_at` ↔ `lastVerifiedAt`: 서버 `datetime | None` ↔ 앱 `DateTime?`.
- `mostRecentChallengeProvider` 반환 타입 `ChallengeSummary?` 일관.
- Step1 → Step2 통과 `step1Data['icon']` (`String`) ↔ `ChallengeCreateRequest.icon` 일관.

**4. Ambiguity:**
- Step 11.3 의 `_iconController` 위치 (description 직후) — `dispose()` 호출 순서까지 명시했으니 모호 없음.
- Step 14.4 의 `_ChallengePill` 클래스 위치 — `_StatusBarContent` 다음 file-private 클래스로 추가. 위치 명확.

---

## Out of Scope (이 plan 에 없음)

- 챌린지방 (`/challenges/:id`) 에서 이모지 수정 affordance — 별도 plan
- preset emoji chip 그리드
- emoji_picker_flutter 같은 외부 패키지 도입
- ChallengeCard (my-page 목록) 에 이모지 노출
- /challenges 풀스크린 페이지 (gem/streak 페이지 패턴) — pill 직접 진입이라 불필요
