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
            photo_url=None,
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
