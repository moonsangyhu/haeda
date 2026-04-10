"""Tests for scheduler_service.close_expired_challenges (slice-06)."""
import math
import uuid
from datetime import date

import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.challenge import Challenge
from app.models.challenge_member import ChallengeMember
from app.models.user import User
from app.models.verification import Verification
from app.services.scheduler_service import close_expired_challenges

PREFIX = "/api/v1"


def _auth(user: User) -> dict[str, str]:
    return {"Authorization": f"Bearer {user.id}"}


# ---------- fixtures ----------


@pytest_asyncio.fixture
async def expired_daily_challenge(db_session: AsyncSession, user: User) -> Challenge:
    """end_date가 과거인 daily 챌린지 (active 상태)."""
    c = Challenge(
        id=uuid.uuid4(),
        creator_id=user.id,
        title="만료된 운동 챌린지",
        description="30일 운동",
        category="운동",
        start_date=date(2026, 3, 1),
        end_date=date(2026, 3, 30),
        verification_frequency={"type": "daily"},
        photo_required=False,
        invite_code="EXP10001",
        status="active",
    )
    db_session.add(c)
    await db_session.commit()
    await db_session.refresh(c)
    return c


@pytest_asyncio.fixture
async def expired_weekly_challenge(db_session: AsyncSession, user: User) -> Challenge:
    """end_date가 과거인 weekly(3) 챌린지 (active 상태)."""
    c = Challenge(
        id=uuid.uuid4(),
        creator_id=user.id,
        title="만료된 독서 챌린지",
        description="주 3회 독서",
        category="독서",
        start_date=date(2026, 3, 1),
        end_date=date(2026, 3, 28),
        verification_frequency={"type": "weekly", "times_per_week": 3},
        photo_required=False,
        invite_code="EXP20002",
        status="active",
    )
    db_session.add(c)
    await db_session.commit()
    await db_session.refresh(c)
    return c


@pytest_asyncio.fixture
async def future_challenge(db_session: AsyncSession, user: User) -> Challenge:
    """end_date가 미래인 active 챌린지."""
    c = Challenge(
        id=uuid.uuid4(),
        creator_id=user.id,
        title="미래 챌린지",
        description="아직 진행 중",
        category="기타",
        start_date=date(2026, 4, 1),
        end_date=date(2026, 5, 1),
        verification_frequency={"type": "daily"},
        photo_required=False,
        invite_code="FUT30003",
        status="active",
    )
    db_session.add(c)
    await db_session.commit()
    await db_session.refresh(c)
    return c


@pytest_asyncio.fixture
async def already_completed_challenge(db_session: AsyncSession, user: User) -> Challenge:
    """이미 completed 상태인 과거 챌린지."""
    c = Challenge(
        id=uuid.uuid4(),
        creator_id=user.id,
        title="이미 완료된 챌린지",
        description="완료됨",
        category="운동",
        start_date=date(2026, 2, 1),
        end_date=date(2026, 2, 28),
        verification_frequency={"type": "daily"},
        photo_required=False,
        invite_code="DONE4444",
        status="completed",
    )
    db_session.add(c)
    await db_session.commit()
    await db_session.refresh(c)
    return c


@pytest_asyncio.fixture
async def daily_members_and_verifications(
    db_session: AsyncSession,
    expired_daily_challenge: Challenge,
    user: User,
    other_user: User,
):
    """user: 26일 인증, other_user: 20일 인증 (daily 30일 챌린지)."""
    c = expired_daily_challenge
    # members
    m1 = ChallengeMember(id=uuid.uuid4(), challenge_id=c.id, user_id=user.id)
    m2 = ChallengeMember(id=uuid.uuid4(), challenge_id=c.id, user_id=other_user.id)
    db_session.add_all([m1, m2])

    # user: 26 verifications
    for i in range(26):
        db_session.add(
            Verification(
                id=uuid.uuid4(),
                challenge_id=c.id,
                user_id=user.id,
                date=date(2026, 3, 1 + i),
                diary_text=f"day {i + 1}",
            )
        )
    # other_user: 20 verifications
    for i in range(20):
        db_session.add(
            Verification(
                id=uuid.uuid4(),
                challenge_id=c.id,
                user_id=other_user.id,
                date=date(2026, 3, 1 + i),
                diary_text=f"day {i + 1}",
            )
        )
    await db_session.commit()
    return m1, m2


@pytest_asyncio.fixture
async def weekly_members_and_verifications(
    db_session: AsyncSession,
    expired_weekly_challenge: Challenge,
    user: User,
):
    """user: 10일 인증 (weekly(3) 28일 챌린지). expected = ceil(28/7)*3 = 12."""
    c = expired_weekly_challenge
    m = ChallengeMember(id=uuid.uuid4(), challenge_id=c.id, user_id=user.id)
    db_session.add(m)

    for i in range(10):
        db_session.add(
            Verification(
                id=uuid.uuid4(),
                challenge_id=c.id,
                user_id=user.id,
                date=date(2026, 3, 1 + i),
                diary_text=f"day {i + 1}",
            )
        )
    await db_session.commit()
    return m


# ---------- tests ----------


@pytest.mark.asyncio
async def test_close_daily_challenge(
    db_session: AsyncSession,
    expired_daily_challenge: Challenge,
    daily_members_and_verifications,
):
    """daily 챌린지 종료 → status=completed, 멤버 badge=completed."""
    m1, m2 = daily_members_and_verifications

    count = await close_expired_challenges(db_session, today=date(2026, 4, 1))

    assert count == 1

    # challenge status
    await db_session.refresh(expired_daily_challenge)
    assert expired_daily_challenge.status == "completed"

    # badges
    await db_session.refresh(m1)
    await db_session.refresh(m2)
    assert m1.badge == "completed"
    assert m2.badge == "completed"


@pytest.mark.asyncio
async def test_close_weekly_challenge(
    db_session: AsyncSession,
    expired_weekly_challenge: Challenge,
    weekly_members_and_verifications,
):
    """weekly(3) 챌린지 종료 → status=completed, badge=completed."""
    m = weekly_members_and_verifications

    count = await close_expired_challenges(db_session, today=date(2026, 4, 1))
    assert count == 1

    await db_session.refresh(expired_weekly_challenge)
    assert expired_weekly_challenge.status == "completed"

    await db_session.refresh(m)
    assert m.badge == "completed"


@pytest.mark.asyncio
async def test_already_completed_not_reprocessed(
    db_session: AsyncSession,
    already_completed_challenge: Challenge,
):
    """이미 completed인 챌린지는 재처리되지 않음."""
    count = await close_expired_challenges(db_session, today=date(2026, 4, 1))
    assert count == 0


@pytest.mark.asyncio
async def test_future_challenge_not_closed(
    db_session: AsyncSession,
    future_challenge: Challenge,
):
    """end_date >= today인 챌린지는 종료되지 않음."""
    # today=2026-04-01, end_date=2026-05-01 → 종료 안됨
    count = await close_expired_challenges(db_session, today=date(2026, 4, 1))
    assert count == 0

    await db_session.refresh(future_challenge)
    assert future_challenge.status == "active"


@pytest.mark.asyncio
async def test_ongoing_challenge_not_closed(
    db_session: AsyncSession,
    expired_daily_challenge: Challenge,
):
    """end_date == today인 챌린지도 종료되지 않음 (< today 조건)."""
    # end_date=2026-03-30, today=2026-03-30 → not < today
    count = await close_expired_challenges(db_session, today=date(2026, 3, 30))
    assert count == 0


@pytest.mark.asyncio
async def test_daily_expected_days_calculation(
    db_session: AsyncSession,
    expired_daily_challenge: Challenge,
    daily_members_and_verifications,
):
    """daily 챌린지: expected_days = total_days = 30."""
    c = expired_daily_challenge
    total_days = (c.end_date - c.start_date).days + 1
    assert total_days == 30

    # user: 26/30 = 86.7%
    # other_user: 20/30 = 66.7%
    assert round(26 / 30 * 100, 1) == 86.7
    assert round(20 / 30 * 100, 1) == 66.7


@pytest.mark.asyncio
async def test_weekly_expected_days_calculation(
    db_session: AsyncSession,
    expired_weekly_challenge: Challenge,
    weekly_members_and_verifications,
):
    """weekly(3) 챌린지: expected = ceil(28/7)*3 = 12. user: 10/12 = 83.3%."""
    c = expired_weekly_challenge
    total_days = (c.end_date - c.start_date).days + 1
    assert total_days == 28

    expected = math.ceil(total_days / 7) * 3
    assert expected == 12

    assert round(10 / 12 * 100, 1) == 83.3


@pytest.mark.asyncio
async def test_completion_after_scheduler(
    client: AsyncClient,
    db_session: AsyncSession,
    user: User,
    other_user: User,
    expired_daily_challenge: Challenge,
    daily_members_and_verifications,
):
    """scheduler 실행 후 GET /challenges/{id}/completion이 기대 결과를 반환."""
    await close_expired_challenges(db_session, today=date(2026, 4, 1))

    resp = await client.get(
        f"{PREFIX}/challenges/{expired_daily_challenge.id}/completion",
        headers=_auth(user),
    )
    assert resp.status_code == 200
    data = resp.json()["data"]

    assert data["challenge_id"] == str(expired_daily_challenge.id)
    assert data["total_days"] == 30

    my = data["my_result"]
    assert my["verified_days"] == 26
    assert my["badge"] == "completed"
    assert my["achievement_rate"] == 86.7

    members = data["members"]
    assert len(members) == 2
    assert members[0]["achievement_rate"] >= members[1]["achievement_rate"]


@pytest.mark.asyncio
async def test_me_challenges_after_scheduler(
    client: AsyncClient,
    db_session: AsyncSession,
    user: User,
    other_user: User,
    expired_daily_challenge: Challenge,
    daily_members_and_verifications,
):
    """scheduler 실행 후 GET /me/challenges?status=completed 에서 badge 반영 확인."""
    await close_expired_challenges(db_session, today=date(2026, 4, 1))

    resp = await client.get(
        f"{PREFIX}/me/challenges?status=completed",
        headers=_auth(user),
    )
    assert resp.status_code == 200
    challenges = resp.json()["data"]["challenges"]

    assert len(challenges) >= 1
    completed = [c for c in challenges if c["id"] == str(expired_daily_challenge.id)]
    assert len(completed) == 1
    assert completed[0]["badge"] == "completed"
    assert completed[0]["status"] == "completed"
    assert completed[0]["achievement_rate"] == 86.7
