"""GET /verifications/{id}, GET /verifications/{id}/comments, POST /verifications/{id}/comments 엔드포인트 테스트"""
import uuid
from datetime import date

import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.challenge import Challenge
from app.models.challenge_member import ChallengeMember
from app.models.comment import Comment
from app.models.user import User
from app.models.verification import Verification


# ---------- 픽스처 ----------

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
        photo_url=None,
        diary_text="오늘 5km 달렸다!",
    )
    db_session.add(v)
    await db_session.commit()
    await db_session.refresh(v)
    return v


# ---------- GET /verifications/{id} ----------

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
    assert data["photo_url"] is None
    assert "created_at" in data
    assert data["user"]["id"] == str(user.id)
    assert data["user"]["nickname"] == "테스터"
    assert data["comments"] == []


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


# ---------- GET /verifications/{id}/comments ----------

@pytest.mark.asyncio
async def test_comments_list_happy_path(
    client: AsyncClient,
    db_session: AsyncSession,
    user: User,
    other_user: User,
    challenge: Challenge,
    membership: ChallengeMember,
    verification: Verification,
):
    """댓글 목록 조회 성공"""
    # other_user도 챌린지 멤버로 추가
    other_membership = ChallengeMember(
        id=uuid.uuid4(),
        challenge_id=challenge.id,
        user_id=other_user.id,
        badge=None,
    )
    db_session.add(other_membership)

    # 댓글 2개 삽입 (created_at을 명시하여 정렬 순서 보장)
    from datetime import datetime, timezone, timedelta

    now = datetime.now(timezone.utc)
    c1 = Comment(
        id=uuid.uuid4(),
        verification_id=verification.id,
        author_id=user.id,
        content="첫 번째 댓글",
        created_at=now,
    )
    c2 = Comment(
        id=uuid.uuid4(),
        verification_id=verification.id,
        author_id=other_user.id,
        content="두 번째 댓글",
        created_at=now + timedelta(seconds=1),
    )
    db_session.add(c1)
    db_session.add(c2)
    await db_session.commit()

    resp = await client.get(
        f"/api/v1/verifications/{verification.id}/comments",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert "comments" in data
    assert len(data["comments"]) == 2
    assert data["comments"][0]["content"] == "첫 번째 댓글"
    assert data["comments"][0]["author"]["id"] == str(user.id)
    assert data["comments"][1]["content"] == "두 번째 댓글"
    assert data["next_cursor"] is None


# ---------- POST /verifications/{id}/comments ----------

@pytest.mark.asyncio
async def test_comment_create_happy_path(
    client: AsyncClient,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
    verification: Verification,
):
    """댓글 작성 성공"""
    resp = await client.post(
        f"/api/v1/verifications/{verification.id}/comments",
        headers={"Authorization": f"Bearer {user.id}"},
        json={"content": "대단해요!"},
    )
    assert resp.status_code == 201
    data = resp.json()["data"]
    assert "id" in data
    assert data["content"] == "대단해요!"
    assert data["author"]["id"] == str(user.id)
    assert data["author"]["nickname"] == "테스터"
    assert "created_at" in data


@pytest.mark.asyncio
async def test_comment_create_too_long(
    client: AsyncClient,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
    verification: Verification,
):
    """500자 초과 댓글: COMMENT_TOO_LONG (422)"""
    long_content = "가" * 501
    resp = await client.post(
        f"/api/v1/verifications/{verification.id}/comments",
        headers={"Authorization": f"Bearer {user.id}"},
        json={"content": long_content},
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "COMMENT_TOO_LONG"


@pytest.mark.asyncio
async def test_comment_create_not_member(
    client: AsyncClient,
    other_user: User,
    challenge: Challenge,
    membership: ChallengeMember,
    verification: Verification,
):
    """챌린지 미참여자 댓글 작성 시도: NOT_A_MEMBER (403)"""
    resp = await client.post(
        f"/api/v1/verifications/{verification.id}/comments",
        headers={"Authorization": f"Bearer {other_user.id}"},
        json={"content": "비멤버 댓글"},
    )
    assert resp.status_code == 403
    assert resp.json()["error"]["code"] == "NOT_A_MEMBER"


@pytest.mark.asyncio
async def test_comment_create_verification_not_found(
    client: AsyncClient,
    user: User,
):
    """존재하지 않는 인증에 댓글: VERIFICATION_NOT_FOUND (404)"""
    fake_id = uuid.uuid4()
    resp = await client.post(
        f"/api/v1/verifications/{fake_id}/comments",
        headers={"Authorization": f"Bearer {user.id}"},
        json={"content": "없는 인증에 댓글"},
    )
    assert resp.status_code == 404
    assert resp.json()["error"]["code"] == "VERIFICATION_NOT_FOUND"
