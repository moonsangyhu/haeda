"""GET /me/challenges 엔드포인트 테스트"""
import uuid
from datetime import date

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.challenge import Challenge
from app.models.challenge_member import ChallengeMember
from app.models.user import User
from app.models.verification import Verification


@pytest.mark.asyncio
async def test_get_my_challenges_returns_list(
    client: AsyncClient, user: User, challenge: Challenge, membership: ChallengeMember
):
    resp = await client.get(
        "/api/v1/me/challenges",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert "data" in body
    challenges = body["data"]["challenges"]
    assert len(challenges) == 1
    item = challenges[0]
    assert item["id"] == str(challenge.id)
    assert item["title"] == "운동 30일"
    assert item["status"] == "active"
    assert item["member_count"] == 1
    assert item["achievement_rate"] == 0.0
    assert item["badge"] is None


@pytest.mark.asyncio
async def test_get_my_challenges_with_status_filter(
    client: AsyncClient,
    db_session: AsyncSession,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    resp = await client.get(
        "/api/v1/me/challenges?status=active",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 200
    assert len(resp.json()["data"]["challenges"]) == 1

    resp2 = await client.get(
        "/api/v1/me/challenges?status=completed",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp2.status_code == 200
    assert len(resp2.json()["data"]["challenges"]) == 0


@pytest.mark.asyncio
async def test_get_my_challenges_achievement_rate(
    client: AsyncClient,
    db_session: AsyncSession,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    # 30일 챌린지에서 10번 인증
    for i in range(1, 11):
        v = Verification(
            challenge_id=challenge.id,
            user_id=user.id,
            date=date(2026, 4, i),
            photo_urls=None,
            diary_text=f"day {i}",
        )
        db_session.add(v)
    await db_session.commit()

    resp = await client.get(
        "/api/v1/me/challenges",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 200
    item = resp.json()["data"]["challenges"][0]
    # 10 / 30 * 100 = 33.3
    assert item["achievement_rate"] == 33.3


@pytest.mark.asyncio
async def test_get_my_challenges_empty(
    client: AsyncClient, user: User
):
    """참여 챌린지가 없는 유저 → 빈 배열"""
    resp = await client.get(
        "/api/v1/me/challenges",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 200
    assert resp.json()["data"]["challenges"] == []


@pytest.mark.asyncio
async def test_get_my_challenges_no_token(client: AsyncClient):
    resp = await client.get("/api/v1/me/challenges")
    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "UNAUTHORIZED"


# ---------- icon + last_verified_at + 정렬 ----------


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
    assert item["icon"] == "🎯"


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
    assert "T" in item["last_verified_at"]


@pytest.mark.asyncio
async def test_get_my_challenges_sorted_by_last_verified_at(
    client: AsyncClient,
    db_session: AsyncSession,
    user: User,
):
    """3 challenges: A (verified yesterday), B (verified today), C (no verif).
    Response order: B, A, C (last_verified_at DESC NULLS LAST)."""
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
            invite_code=f"PILL{title}01"[:8],
            status="active",
        )
        db_session.add(c)
        await db_session.flush()
        m = ChallengeMember(challenge_id=c.id, user_id=user.id)
        db_session.add(m)
        chals.append(c)

    from datetime import datetime as dt, timezone as tz
    today = date(2026, 4, 28)
    yesterday = date(2026, 4, 27)
    db_session.add(
        Verification(
            challenge_id=chals[0].id,
            user_id=user.id,
            date=yesterday,
            photo_urls=None,
            diary_text="A",
            created_at=dt(2026, 4, 27, 10, 0, 0, tzinfo=tz.utc),
        )
    )
    db_session.add(
        Verification(
            challenge_id=chals[1].id,
            user_id=user.id,
            date=today,
            photo_urls=None,
            diary_text="B",
            created_at=dt(2026, 4, 28, 10, 0, 0, tzinfo=tz.utc),
        )
    )
    await db_session.commit()

    resp = await client.get(
        "/api/v1/me/challenges",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    titles = [c["title"] for c in resp.json()["data"]["challenges"]]
    assert titles == ["B", "A", "C"]
