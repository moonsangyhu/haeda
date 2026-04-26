import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.friendship import Friendship
from app.models.user import User


def _auth(user: User) -> dict:
    return {"Authorization": f"Bearer {user.id}"}


@pytest.mark.asyncio
async def test_search_by_id_returns_user(
    client: AsyncClient, db_session: AsyncSession, user: User
):
    target = User(kakao_id=10, nickname="대상", discriminator="55555")
    db_session.add(target)
    await db_session.commit()
    await db_session.refresh(target)

    resp = await client.post(
        "/api/v1/users/search-by-id",
        headers=_auth(user),
        json={"nickname": "대상", "discriminator": "55555"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["user_id"] == str(target.id)
    assert data["nickname"] == "대상"
    assert data["discriminator"] == "55555"
    assert data["friendship_status"] == "none"


@pytest.mark.asyncio
async def test_search_by_id_self_returns_self_status(
    client: AsyncClient, user: User
):
    resp = await client.post(
        "/api/v1/users/search-by-id",
        headers=_auth(user),
        json={
            "nickname": user.nickname,
            "discriminator": user.discriminator,
        },
    )
    assert resp.status_code == 200
    assert resp.json()["data"]["friendship_status"] == "self"


@pytest.mark.asyncio
async def test_search_by_id_accepted_friend(
    client: AsyncClient, db_session: AsyncSession, user: User
):
    friend = User(kakao_id=20, nickname="친구", discriminator="22222")
    db_session.add(friend)
    await db_session.flush()
    db_session.add(
        Friendship(
            requester_id=user.id,
            addressee_id=friend.id,
            status="accepted",
        )
    )
    await db_session.commit()

    resp = await client.post(
        "/api/v1/users/search-by-id",
        headers=_auth(user),
        json={"nickname": "친구", "discriminator": "22222"},
    )
    assert resp.json()["data"]["friendship_status"] == "accepted"


@pytest.mark.asyncio
async def test_search_by_id_pending_friend(
    client: AsyncClient, db_session: AsyncSession, user: User
):
    other = User(kakao_id=30, nickname="요청", discriminator="11111")
    db_session.add(other)
    await db_session.flush()
    db_session.add(
        Friendship(
            requester_id=user.id,
            addressee_id=other.id,
            status="pending",
        )
    )
    await db_session.commit()

    resp = await client.post(
        "/api/v1/users/search-by-id",
        headers=_auth(user),
        json={"nickname": "요청", "discriminator": "11111"},
    )
    assert resp.json()["data"]["friendship_status"] == "pending"


@pytest.mark.asyncio
async def test_search_by_id_not_found(
    client: AsyncClient, user: User
):
    resp = await client.post(
        "/api/v1/users/search-by-id",
        headers=_auth(user),
        json={"nickname": "없는유저", "discriminator": "99999"},
    )
    assert resp.status_code == 404
    assert resp.json()["error"]["code"] == "USER_NOT_FOUND"


@pytest.mark.asyncio
async def test_search_by_id_invalid_format(
    client: AsyncClient, user: User
):
    resp = await client.post(
        "/api/v1/users/search-by-id",
        headers=_auth(user),
        json={"nickname": "x", "discriminator": "ABC"},  # 숫자 아님
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_search_by_id_requires_auth(client: AsyncClient):
    resp = await client.post(
        "/api/v1/users/search-by-id",
        json={"nickname": "x", "discriminator": "12345"},
    )
    assert resp.status_code == 401
