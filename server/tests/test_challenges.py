"""GET /challenges/{id} 및 GET /challenges/{id}/calendar 엔드포인트 테스트"""
import uuid
from datetime import date

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.challenge import Challenge
from app.models.challenge_member import ChallengeMember
from app.models.day_completion import DayCompletion
from app.models.user import User
from app.models.verification import Verification


# ---------- GET /challenges/{id} ----------

@pytest.mark.asyncio
async def test_get_challenge_detail_success(
    client: AsyncClient,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    resp = await client.get(
        f"/api/v1/challenges/{challenge.id}",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["id"] == str(challenge.id)
    assert data["title"] == "운동 30일"
    assert data["invite_code"] == "ABCD1234"
    assert data["is_member"] is True
    assert data["member_count"] == 1
    assert data["creator"]["id"] == str(user.id)
    assert data["creator"]["nickname"] == "테스터"


@pytest.mark.asyncio
async def test_get_challenge_detail_not_member(
    client: AsyncClient,
    other_user: User,
    challenge: Challenge,
):
    # other_user는 챌린지에 참여하지 않음
    resp = await client.get(
        f"/api/v1/challenges/{challenge.id}",
        headers={"Authorization": f"Bearer {other_user.id}"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["is_member"] is False


@pytest.mark.asyncio
async def test_get_challenge_detail_not_found(
    client: AsyncClient, user: User
):
    fake_id = uuid.uuid4()
    resp = await client.get(
        f"/api/v1/challenges/{fake_id}",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 404
    assert resp.json()["error"]["code"] == "CHALLENGE_NOT_FOUND"


# ---------- GET /challenges/{id}/calendar ----------

@pytest.mark.asyncio
async def test_get_calendar_success(
    client: AsyncClient,
    db_session: AsyncSession,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    # 4월 1일에 인증 추가
    v = Verification(
        challenge_id=challenge.id,
        user_id=user.id,
        date=date(2026, 4, 1),
        photo_urls=None,
        diary_text="운동 완료",
    )
    db_session.add(v)
    # 4월 1일 DayCompletion 추가
    dc = DayCompletion(
        challenge_id=challenge.id,
        date=date(2026, 4, 1),
        season_icon_type="spring",
    )
    db_session.add(dc)
    await db_session.commit()

    resp = await client.get(
        f"/api/v1/challenges/{challenge.id}/calendar?year=2026&month=4",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["challenge_id"] == str(challenge.id)
    assert data["year"] == 2026
    assert data["month"] == 4
    assert len(data["members"]) == 1
    assert data["members"][0]["id"] == str(user.id)

    days = data["days"]
    assert len(days) == 1
    day = days[0]
    assert day["date"] == "2026-04-01"
    assert str(user.id) in day["verified_members"]
    assert day["all_completed"] is True
    assert day["season_icon_type"] == "spring"


@pytest.mark.asyncio
async def test_get_calendar_not_a_member(
    client: AsyncClient,
    other_user: User,
    challenge: Challenge,
):
    resp = await client.get(
        f"/api/v1/challenges/{challenge.id}/calendar?year=2026&month=4",
        headers={"Authorization": f"Bearer {other_user.id}"},
    )
    assert resp.status_code == 403
    assert resp.json()["error"]["code"] == "NOT_A_MEMBER"


@pytest.mark.asyncio
async def test_get_calendar_challenge_not_found(
    client: AsyncClient, user: User
):
    fake_id = uuid.uuid4()
    resp = await client.get(
        f"/api/v1/challenges/{fake_id}/calendar?year=2026&month=4",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 404
    assert resp.json()["error"]["code"] == "CHALLENGE_NOT_FOUND"


@pytest.mark.asyncio
async def test_get_calendar_empty_month(
    client: AsyncClient,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    # 인증이 없는 달 요청
    resp = await client.get(
        f"/api/v1/challenges/{challenge.id}/calendar?year=2026&month=3",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["days"] == []


# ---------- Challenge settings ----------


@pytest.mark.asyncio
async def test_create_challenge_with_day_cutoff_hour(client: AsyncClient, user: User):
    """챌린지 생성 시 day_cutoff_hour=2 설정 → 응답에 포함"""
    resp = await client.post(
        "/api/v1/challenges",
        json={
            "title": "새벽 루틴",
            "category": "건강",
            "start_date": "2026-04-05",
            "end_date": "2026-05-04",
            "verification_frequency": {"type": "daily"},
            "photo_required": False,
            "day_cutoff_hour": 2,
        },
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 201
    assert resp.json()["data"]["day_cutoff_hour"] == 2


@pytest.mark.asyncio
async def test_update_challenge_settings_creator(
    client: AsyncClient,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    """챌린지 생성자가 settings 변경 → 200"""
    resp = await client.patch(
        f"/api/v1/challenges/{challenge.id}/settings",
        json={"day_cutoff_hour": 1},
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 200
    assert resp.json()["data"]["day_cutoff_hour"] == 1


@pytest.mark.asyncio
async def test_update_challenge_settings_not_creator(
    client: AsyncClient,
    other_user: User,
    challenge: Challenge,
):
    """비생성자가 settings 변경 시도 → 403 NOT_CHALLENGE_CREATOR"""
    resp = await client.patch(
        f"/api/v1/challenges/{challenge.id}/settings",
        json={"day_cutoff_hour": 2},
        headers={"Authorization": f"Bearer {other_user.id}"},
    )
    assert resp.status_code == 403
    assert resp.json()["error"]["code"] == "NOT_CHALLENGE_CREATOR"


@pytest.mark.asyncio
async def test_update_challenge_settings_invalid_value(
    client: AsyncClient,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    """day_cutoff_hour=3 → 422 INVALID_DAY_CUTOFF_HOUR"""
    resp = await client.patch(
        f"/api/v1/challenges/{challenge.id}/settings",
        json={"day_cutoff_hour": 3},
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "INVALID_DAY_CUTOFF_HOUR"


# ---------- icon 필드 ----------

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
