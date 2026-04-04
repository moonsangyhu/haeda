"""POST /challenges/{id}/verifications, GET /challenges/{id}/verifications/{date} 엔드포인트 테스트"""
import uuid
from datetime import date
from io import BytesIO
from unittest.mock import patch

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.challenge import Challenge
from app.models.challenge_member import ChallengeMember
from app.models.day_completion import DayCompletion
from app.models.user import User
from app.models.verification import Verification


# ---------- POST /challenges/{id}/verifications ----------

@pytest.mark.asyncio
async def test_create_verification_success(
    client: AsyncClient,
    db_session: AsyncSession,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    """happy path: 인증 제출 성공"""
    today = date.today()
    with patch("app.services.verification_service.date") as mock_date:
        mock_date.today.return_value = date(2026, 4, 5)
        mock_date.side_effect = lambda *args, **kwargs: date(*args, **kwargs)

        resp = await client.post(
            f"/api/v1/challenges/{challenge.id}/verifications",
            headers={"Authorization": f"Bearer {user.id}"},
            data={"diary_text": "오늘 운동 완료!"},
        )

    assert resp.status_code == 201
    data = resp.json()["data"]
    assert data["diary_text"] == "오늘 운동 완료!"
    assert data["photo_url"] is None
    assert "id" in data
    assert "created_at" in data
    assert "day_completed" in data
    assert "season_icon_type" in data


@pytest.mark.asyncio
async def test_create_verification_duplicate(
    client: AsyncClient,
    db_session: AsyncSession,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    """중복 인증: ALREADY_VERIFIED_TODAY (409)"""
    today = date(2026, 4, 5)

    # 먼저 인증 레코드를 직접 DB에 삽입
    v = Verification(
        id=uuid.uuid4(),
        challenge_id=challenge.id,
        user_id=user.id,
        date=today,
        photo_url=None,
        diary_text="먼저 인증",
    )
    db_session.add(v)
    await db_session.commit()

    with patch("app.services.verification_service.date") as mock_date:
        mock_date.today.return_value = today
        mock_date.side_effect = lambda *args, **kwargs: date(*args, **kwargs)

        resp = await client.post(
            f"/api/v1/challenges/{challenge.id}/verifications",
            headers={"Authorization": f"Bearer {user.id}"},
            data={"diary_text": "두 번째 인증 시도"},
        )

    assert resp.status_code == 409
    assert resp.json()["error"]["code"] == "ALREADY_VERIFIED_TODAY"


@pytest.mark.asyncio
async def test_create_verification_photo_required(
    client: AsyncClient,
    db_session: AsyncSession,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    """사진 필수 챌린지에 사진 없이 인증: PHOTO_REQUIRED (400)"""
    # challenge를 photo_required=True로 업데이트
    challenge.photo_required = True
    db_session.add(challenge)
    await db_session.commit()

    with patch("app.services.verification_service.date") as mock_date:
        mock_date.today.return_value = date(2026, 4, 5)
        mock_date.side_effect = lambda *args, **kwargs: date(*args, **kwargs)

        resp = await client.post(
            f"/api/v1/challenges/{challenge.id}/verifications",
            headers={"Authorization": f"Bearer {user.id}"},
            data={"diary_text": "사진 없이 인증"},
        )

    assert resp.status_code == 400
    assert resp.json()["error"]["code"] == "PHOTO_REQUIRED"


@pytest.mark.asyncio
async def test_create_verification_not_member(
    client: AsyncClient,
    other_user: User,
    challenge: Challenge,
):
    """챌린지 미참여자 인증 시도: NOT_A_MEMBER (403)"""
    with patch("app.services.verification_service.date") as mock_date:
        mock_date.today.return_value = date(2026, 4, 5)
        mock_date.side_effect = lambda *args, **kwargs: date(*args, **kwargs)

        resp = await client.post(
            f"/api/v1/challenges/{challenge.id}/verifications",
            headers={"Authorization": f"Bearer {other_user.id}"},
            data={"diary_text": "비멤버 인증 시도"},
        )

    assert resp.status_code == 403
    assert resp.json()["error"]["code"] == "NOT_A_MEMBER"


@pytest.mark.asyncio
async def test_create_verification_challenge_not_found(
    client: AsyncClient,
    user: User,
):
    """존재하지 않는 챌린지: CHALLENGE_NOT_FOUND (404)"""
    fake_id = uuid.uuid4()

    with patch("app.services.verification_service.date") as mock_date:
        mock_date.today.return_value = date(2026, 4, 5)
        mock_date.side_effect = lambda *args, **kwargs: date(*args, **kwargs)

        resp = await client.post(
            f"/api/v1/challenges/{fake_id}/verifications",
            headers={"Authorization": f"Bearer {user.id}"},
            data={"diary_text": "없는 챌린지 인증"},
        )

    assert resp.status_code == 404
    assert resp.json()["error"]["code"] == "CHALLENGE_NOT_FOUND"


@pytest.mark.asyncio
async def test_create_verification_day_completion(
    client: AsyncClient,
    db_session: AsyncSession,
    user: User,
    other_user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    """전원 인증 시 DayCompletion 생성 확인"""
    from sqlalchemy import select

    # other_user도 챌린지에 참여시킴
    other_membership = ChallengeMember(
        id=uuid.uuid4(),
        challenge_id=challenge.id,
        user_id=other_user.id,
        badge=None,
    )
    db_session.add(other_membership)
    await db_session.commit()

    today = date(2026, 4, 5)

    # user가 먼저 인증 (전원 아직 아님)
    with patch("app.services.verification_service.date") as mock_date:
        mock_date.today.return_value = today
        mock_date.side_effect = lambda *args, **kwargs: date(*args, **kwargs)

        resp1 = await client.post(
            f"/api/v1/challenges/{challenge.id}/verifications",
            headers={"Authorization": f"Bearer {user.id}"},
            data={"diary_text": "user 인증"},
        )
    assert resp1.status_code == 201
    data1 = resp1.json()["data"]
    assert data1["day_completed"] is False

    # other_user가 인증 → 전원 인증 달성
    with patch("app.services.verification_service.date") as mock_date:
        mock_date.today.return_value = today
        mock_date.side_effect = lambda *args, **kwargs: date(*args, **kwargs)

        resp2 = await client.post(
            f"/api/v1/challenges/{challenge.id}/verifications",
            headers={"Authorization": f"Bearer {other_user.id}"},
            data={"diary_text": "other_user 인증"},
        )
    assert resp2.status_code == 201
    data2 = resp2.json()["data"]
    assert data2["day_completed"] is True
    assert data2["season_icon_type"] == "spring"  # 4월 → spring

    # DayCompletion 레코드가 DB에 생성되었는지 확인
    dc_stmt = select(DayCompletion).where(
        DayCompletion.challenge_id == challenge.id,
        DayCompletion.date == today,
    )
    dc_result = await db_session.execute(dc_stmt)
    dc = dc_result.scalar_one_or_none()
    assert dc is not None
    assert dc.season_icon_type == "spring"


# ---------- GET /challenges/{id}/verifications/{date} ----------

@pytest.mark.asyncio
async def test_get_daily_verifications_success(
    client: AsyncClient,
    db_session: AsyncSession,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    """특정 날짜 인증 목록 조회 성공"""
    target_date = date(2026, 4, 5)

    # 인증 레코드 삽입
    v = Verification(
        id=uuid.uuid4(),
        challenge_id=challenge.id,
        user_id=user.id,
        date=target_date,
        photo_url=None,
        diary_text="오늘 달리기!",
    )
    db_session.add(v)
    # DayCompletion 삽입 (1인 챌린지이므로 전원 인증)
    dc = DayCompletion(
        id=uuid.uuid4(),
        challenge_id=challenge.id,
        date=target_date,
        season_icon_type="spring",
    )
    db_session.add(dc)
    await db_session.commit()

    resp = await client.get(
        f"/api/v1/challenges/{challenge.id}/verifications/2026-04-05",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["date"] == "2026-04-05"
    assert data["all_completed"] is True
    assert data["season_icon_type"] == "spring"
    assert len(data["verifications"]) == 1
    v_item = data["verifications"][0]
    assert v_item["diary_text"] == "오늘 달리기!"
    assert v_item["photo_url"] is None
    assert v_item["comment_count"] == 0
    assert v_item["user"]["id"] == str(user.id)
    assert v_item["user"]["nickname"] == "테스터"


@pytest.mark.asyncio
async def test_get_daily_verifications_empty(
    client: AsyncClient,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    """인증이 없는 날짜: 빈 목록 반환"""
    resp = await client.get(
        f"/api/v1/challenges/{challenge.id}/verifications/2026-04-05",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["date"] == "2026-04-05"
    assert data["all_completed"] is False
    assert data["season_icon_type"] is None
    assert data["verifications"] == []


@pytest.mark.asyncio
async def test_get_daily_verifications_not_member(
    client: AsyncClient,
    other_user: User,
    challenge: Challenge,
):
    """미참여자 조회 시도: NOT_A_MEMBER (403)"""
    resp = await client.get(
        f"/api/v1/challenges/{challenge.id}/verifications/2026-04-05",
        headers={"Authorization": f"Bearer {other_user.id}"},
    )
    assert resp.status_code == 403
    assert resp.json()["error"]["code"] == "NOT_A_MEMBER"
