"""POST /challenges, GET /challenges/invite/{code}, POST /challenges/{id}/join 테스트"""
import uuid
from datetime import date

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.challenge import Challenge
from app.models.challenge_member import ChallengeMember
from app.models.user import User


# ---------- POST /challenges ----------

@pytest.mark.asyncio
async def test_create_challenge_happy_path(
    client: AsyncClient,
    user: User,
):
    resp = await client.post(
        "/api/v1/challenges",
        json={
            "title": "운동 30일",
            "description": "매일 30분 이상 운동하기",
            "category": "운동",
            "start_date": "2026-04-05",
            "end_date": "2026-05-04",
            "verification_frequency": {"type": "daily"},
            "photo_required": True,
        },
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 201
    data = resp.json()["data"]
    assert data["title"] == "운동 30일"
    assert data["description"] == "매일 30분 이상 운동하기"
    assert data["category"] == "운동"
    assert data["start_date"] == "2026-04-05"
    assert data["end_date"] == "2026-05-04"
    assert data["verification_frequency"] == {"type": "daily"}
    assert data["photo_required"] is True
    assert data["status"] == "active"
    assert data["member_count"] == 1
    assert data["creator"]["id"] == str(user.id)
    # invite_code: 8자리 대문자+숫자
    invite_code = data["invite_code"]
    assert len(invite_code) == 8
    assert invite_code.isalnum()
    assert invite_code == invite_code.upper()
    assert "id" in data
    assert "created_at" in data


@pytest.mark.asyncio
async def test_create_challenge_invalid_date_range(
    client: AsyncClient,
    user: User,
):
    resp = await client.post(
        "/api/v1/challenges",
        json={
            "title": "잘못된 날짜",
            "category": "기타",
            "start_date": "2026-05-04",
            "end_date": "2026-04-05",  # end <= start
            "verification_frequency": {"type": "daily"},
        },
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "INVALID_DATE_RANGE"


@pytest.mark.asyncio
async def test_create_challenge_invalid_date_range_equal(
    client: AsyncClient,
    user: User,
):
    resp = await client.post(
        "/api/v1/challenges",
        json={
            "title": "같은 날짜",
            "category": "기타",
            "start_date": "2026-04-05",
            "end_date": "2026-04-05",  # end == start
            "verification_frequency": {"type": "daily"},
        },
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "INVALID_DATE_RANGE"


@pytest.mark.asyncio
async def test_create_challenge_invalid_frequency(
    client: AsyncClient,
    user: User,
):
    resp = await client.post(
        "/api/v1/challenges",
        json={
            "title": "잘못된 빈도",
            "category": "기타",
            "start_date": "2026-04-05",
            "end_date": "2026-05-04",
            "verification_frequency": {"type": "invalid"},
        },
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "INVALID_FREQUENCY"


@pytest.mark.asyncio
async def test_create_challenge_weekly_missing_times(
    client: AsyncClient,
    user: User,
):
    resp = await client.post(
        "/api/v1/challenges",
        json={
            "title": "주간 챌린지",
            "category": "기타",
            "start_date": "2026-04-05",
            "end_date": "2026-05-04",
            "verification_frequency": {"type": "weekly"},  # times_per_week 없음
        },
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "INVALID_FREQUENCY"


# ---------- GET /challenges/invite/{code} ----------

@pytest.mark.asyncio
async def test_invite_lookup_happy_path(
    client: AsyncClient,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    resp = await client.get(
        f"/api/v1/challenges/invite/{challenge.invite_code}",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["id"] == str(challenge.id)
    assert data["invite_code"] == challenge.invite_code
    assert data["title"] == challenge.title
    assert data["is_member"] is True
    assert data["member_count"] == 1
    assert data["creator"]["id"] == str(user.id)


@pytest.mark.asyncio
async def test_invite_lookup_not_member(
    client: AsyncClient,
    other_user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    resp = await client.get(
        f"/api/v1/challenges/invite/{challenge.invite_code}",
        headers={"Authorization": f"Bearer {other_user.id}"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["is_member"] is False


@pytest.mark.asyncio
async def test_invite_lookup_invalid_code(
    client: AsyncClient,
    user: User,
):
    resp = await client.get(
        "/api/v1/challenges/invite/NOTEXIST",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 404
    assert resp.json()["error"]["code"] == "INVALID_INVITE_CODE"


# ---------- POST /challenges/{id}/join ----------

@pytest.mark.asyncio
async def test_join_happy_path(
    client: AsyncClient,
    other_user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    # other_user는 아직 챌린지에 참여하지 않음
    resp = await client.post(
        f"/api/v1/challenges/{challenge.id}/join",
        headers={"Authorization": f"Bearer {other_user.id}"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["challenge_id"] == str(challenge.id)
    assert "joined_at" in data


@pytest.mark.asyncio
async def test_join_already_joined(
    client: AsyncClient,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    # user는 이미 membership 픽스처로 챌린지에 참여 중
    resp = await client.post(
        f"/api/v1/challenges/{challenge.id}/join",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 409
    assert resp.json()["error"]["code"] == "ALREADY_JOINED"


@pytest.mark.asyncio
async def test_join_challenge_not_found(
    client: AsyncClient,
    user: User,
):
    fake_id = uuid.uuid4()
    resp = await client.post(
        f"/api/v1/challenges/{fake_id}/join",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 404
    assert resp.json()["error"]["code"] == "CHALLENGE_NOT_FOUND"


@pytest.mark.asyncio
async def test_join_challenge_ended(
    client: AsyncClient,
    db_session: AsyncSession,
    other_user: User,
    challenge: Challenge,
):
    # challenge를 completed 상태로 변경
    challenge.status = "completed"
    db_session.add(challenge)
    await db_session.commit()

    resp = await client.post(
        f"/api/v1/challenges/{challenge.id}/join",
        headers={"Authorization": f"Bearer {other_user.id}"},
    )
    assert resp.status_code == 400
    assert resp.json()["error"]["code"] == "CHALLENGE_ENDED"


# ---------- icon 필드 테스트 ----------

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
