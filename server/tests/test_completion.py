"""Tests for GET /challenges/{id}/completion (slice-05)."""
import uuid
from datetime import date

import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.challenge import Challenge
from app.models.challenge_member import ChallengeMember
from app.models.day_completion import DayCompletion
from app.models.user import User
from app.models.verification import Verification

PREFIX = "/api/v1/challenges"


def _auth(user: User) -> dict[str, str]:
    return {"Authorization": f"Bearer {user.id}"}


# ---------- fixtures ----------


@pytest_asyncio.fixture
async def completed_challenge(db_session: AsyncSession, user: User) -> Challenge:
    """status='completed' 챌린지 (30일, daily)."""
    c = Challenge(
        id=uuid.uuid4(),
        creator_id=user.id,
        title="운동 30일",
        description="매일 30분 운동",
        category="운동",
        start_date=date(2026, 3, 5),
        end_date=date(2026, 4, 3),
        verification_frequency={"type": "daily"},
        photo_required=False,
        invite_code="DONE1234",
        is_public=False,
        status="completed",
    )
    db_session.add(c)
    await db_session.commit()
    await db_session.refresh(c)
    return c


@pytest_asyncio.fixture
async def completed_membership(
    db_session: AsyncSession, completed_challenge: Challenge, user: User
) -> ChallengeMember:
    m = ChallengeMember(
        id=uuid.uuid4(),
        challenge_id=completed_challenge.id,
        user_id=user.id,
        badge="completed",
    )
    db_session.add(m)
    await db_session.commit()
    await db_session.refresh(m)
    return m


@pytest_asyncio.fixture
async def other_membership(
    db_session: AsyncSession, completed_challenge: Challenge, other_user: User
) -> ChallengeMember:
    m = ChallengeMember(
        id=uuid.uuid4(),
        challenge_id=completed_challenge.id,
        user_id=other_user.id,
        badge="completed",
    )
    db_session.add(m)
    await db_session.commit()
    await db_session.refresh(m)
    return m


@pytest_asyncio.fixture
async def seed_verifications(
    db_session: AsyncSession,
    completed_challenge: Challenge,
    completed_membership: ChallengeMember,
    other_membership: ChallengeMember,
    user: User,
    other_user: User,
):
    """user: 26일 인증, other_user: 20일 인증. 전원인증(DayCompletion) 12일."""
    c = completed_challenge
    # user: 26일 (3/5 ~ 3/30)
    for i in range(26):
        d = date(2026, 3, 5 + i)
        db_session.add(
            Verification(
                id=uuid.uuid4(),
                challenge_id=c.id,
                user_id=user.id,
                date=d,
                diary_text=f"day {i+1}",
            )
        )
    # other_user: 20일 (3/5 ~ 3/24) — 첫 20일만
    for i in range(20):
        d = date(2026, 3, 5 + i)
        db_session.add(
            Verification(
                id=uuid.uuid4(),
                challenge_id=c.id,
                user_id=other_user.id,
                date=d,
                diary_text=f"day {i+1}",
            )
        )
    # DayCompletion: 첫 12일 (3/5 ~ 3/16) — 둘 다 인증한 날 중 12일
    for i in range(12):
        d = date(2026, 3, 5 + i)
        db_session.add(
            DayCompletion(
                id=uuid.uuid4(),
                challenge_id=c.id,
                date=d,
                season_icon_type="spring",
            )
        )
    await db_session.commit()


# ---------- tests ----------


@pytest.mark.asyncio
async def test_completion_happy_path(
    client: AsyncClient,
    user: User,
    other_user: User,
    completed_challenge: Challenge,
    seed_verifications,
):
    resp = await client.get(
        f"{PREFIX}/{completed_challenge.id}/completion",
        headers=_auth(user),
    )
    assert resp.status_code == 200
    data = resp.json()["data"]

    # 기본 필드
    assert data["challenge_id"] == str(completed_challenge.id)
    assert data["title"] == "운동 30일"
    assert data["category"] == "운동"
    assert data["start_date"] == "2026-03-05"
    assert data["end_date"] == "2026-04-03"
    assert data["total_days"] == 30

    # my_result
    my = data["my_result"]
    assert my["user_id"] == str(user.id)
    assert my["verified_days"] == 26
    assert my["expected_days"] == 30
    assert my["badge"] == "completed"
    # 달성률: 26/30 * 100 = 86.7
    assert my["achievement_rate"] == 86.7

    # members (달성률 내림차순)
    members = data["members"]
    assert len(members) == 2
    assert members[0]["achievement_rate"] >= members[1]["achievement_rate"]
    # user(86.7) > other_user(66.7)
    assert members[0]["user_id"] == str(user.id)
    assert members[1]["user_id"] == str(other_user.id)
    assert members[1]["verified_days"] == 20

    # day_completions
    assert data["day_completions"] == 12

    # calendar_summary
    cal = data["calendar_summary"]
    assert cal["total_days"] == 30
    assert cal["all_completed_days"] == 12
    assert "spring" in cal["season_icon_types"]


@pytest.mark.asyncio
async def test_completion_challenge_not_found(client: AsyncClient, user: User):
    fake_id = uuid.uuid4()
    resp = await client.get(
        f"{PREFIX}/{fake_id}/completion",
        headers=_auth(user),
    )
    assert resp.status_code == 404
    assert resp.json()["error"]["code"] == "CHALLENGE_NOT_FOUND"


@pytest.mark.asyncio
async def test_completion_not_a_member(
    client: AsyncClient,
    other_user: User,
    completed_challenge: Challenge,
    completed_membership: ChallengeMember,
):
    """other_user는 멤버가 아님 (completed_membership은 user만)."""
    resp = await client.get(
        f"{PREFIX}/{completed_challenge.id}/completion",
        headers=_auth(other_user),
    )
    assert resp.status_code == 403
    assert resp.json()["error"]["code"] == "NOT_A_MEMBER"


@pytest.mark.asyncio
async def test_completion_challenge_not_completed(
    client: AsyncClient,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    """active 챌린지에 completion 호출 시 에러."""
    resp = await client.get(
        f"{PREFIX}/{challenge.id}/completion",
        headers=_auth(user),
    )
    assert resp.status_code == 400
    assert resp.json()["error"]["code"] == "CHALLENGE_NOT_COMPLETED"
