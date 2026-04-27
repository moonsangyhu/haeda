"""GET /verifications/{id} 엔드포인트 테스트"""
import uuid
from datetime import date

import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.challenge import Challenge
from app.models.challenge_member import ChallengeMember
from app.models.user import User
from app.models.verification import Verification


@pytest_asyncio.fixture
async def verification(
    db_session: AsyncSession,
    challenge: Challenge,
    user: User,
) -> Verification:
    v = Verification(
        id=uuid.uuid4(),
        challenge_id=challenge.id,
        user_id=user.id,
        date=date(2026, 4, 5),
        photo_urls=None,
        diary_text="오늘 5km 달렸다!",
    )
    db_session.add(v)
    await db_session.commit()
    await db_session.refresh(v)
    return v


@pytest.mark.asyncio
async def test_verification_detail_happy_path(
    client: AsyncClient,
    db_session: AsyncSession,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
    verification: Verification,
):
    """인증 상세 조회 성공"""
    resp = await client.get(
        f"/api/v1/verifications/{verification.id}",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["id"] == str(verification.id)
    assert data["challenge_id"] == str(challenge.id)
    assert data["date"] == "2026-04-05"
    assert data["diary_text"] == "오늘 5km 달렸다!"
    assert data["photo_urls"] is None
    assert "created_at" in data
    assert data["user"]["id"] == str(user.id)
    assert data["user"]["nickname"] == "테스터"
    assert data["comments"] == []


@pytest.mark.asyncio
async def test_verification_detail_with_comments(
    client: AsyncClient,
    db_session: AsyncSession,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
    verification: Verification,
):
    """댓글이 있는 인증 상세 조회 — comments 배열에 채워져 반환"""
    from app.models.comment import Comment

    c = Comment(
        id=uuid.uuid4(),
        verification_id=verification.id,
        author_id=user.id,
        content="좋은 인증이네요!",
    )
    db_session.add(c)
    await db_session.commit()

    resp = await client.get(
        f"/api/v1/verifications/{verification.id}",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert len(data["comments"]) == 1
    assert data["comments"][0]["content"] == "좋은 인증이네요!"
    assert data["comments"][0]["author"]["id"] == str(user.id)


@pytest.mark.asyncio
async def test_verification_detail_not_found(
    client: AsyncClient,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    """존재하지 않는 인증: VERIFICATION_NOT_FOUND (404)"""
    fake_id = uuid.uuid4()
    resp = await client.get(
        f"/api/v1/verifications/{fake_id}",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 404
    assert resp.json()["error"]["code"] == "VERIFICATION_NOT_FOUND"


@pytest.mark.asyncio
async def test_verification_detail_not_member(
    client: AsyncClient,
    other_user: User,
    challenge: Challenge,
    membership: ChallengeMember,
    verification: Verification,
):
    """챌린지 미참여자 조회 시도: NOT_A_MEMBER (403)"""
    resp = await client.get(
        f"/api/v1/verifications/{verification.id}",
        headers={"Authorization": f"Bearer {other_user.id}"},
    )
    assert resp.status_code == 403
    assert resp.json()["error"]["code"] == "NOT_A_MEMBER"
