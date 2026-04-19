import uuid
from datetime import datetime, timedelta, timezone

import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.challenge import Challenge
from app.models.challenge_member import ChallengeMember
from app.models.room_speech import RoomSpeech
from app.models.user import User
from app.services import room_speech_service


# ---------- helpers ----------

def _auth(user: User) -> dict:
    return {"Authorization": f"Bearer {user.id}"}


def _speech_url(challenge_id: uuid.UUID) -> str:
    return f"/api/v1/challenges/{challenge_id}/room-speech"


async def _add_member(db: AsyncSession, challenge: Challenge, user: User) -> ChallengeMember:
    m = ChallengeMember(id=uuid.uuid4(), challenge_id=challenge.id, user_id=user.id)
    db.add(m)
    await db.commit()
    return m


async def _insert_expired_speech(
    db: AsyncSession, challenge: Challenge, user: User
) -> RoomSpeech:
    past = datetime.now(tz=timezone.utc) - timedelta(hours=1)
    speech = RoomSpeech(
        id=uuid.uuid4(),
        challenge_id=challenge.id,
        user_id=user.id,
        content="expired말",
        expires_at=past,
    )
    db.add(speech)
    await db.commit()
    await db.refresh(speech)
    return speech


# ---------- tests ----------

@pytest.mark.asyncio
async def test_post_normal(client: AsyncClient, db_session: AsyncSession, user: User, challenge: Challenge):
    room_speech_service.clear_rate_limit_cache()
    await _add_member(db_session, challenge, user)
    resp = await client.post(
        _speech_url(challenge.id),
        json={"content": "오늘 화이팅!"},
        headers=_auth(user),
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["content"] == "오늘 화이팅!"
    assert "expires_at" in data
    assert "created_at" in data


@pytest.mark.asyncio
async def test_post_empty_content(client: AsyncClient, db_session: AsyncSession, user: User, challenge: Challenge):
    room_speech_service.clear_rate_limit_cache()
    await _add_member(db_session, challenge, user)
    resp = await client.post(
        _speech_url(challenge.id),
        json={"content": "   "},
        headers=_auth(user),
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "SPEECH_EMPTY"


@pytest.mark.asyncio
async def test_post_too_long(client: AsyncClient, db_session: AsyncSession, user: User, challenge: Challenge):
    room_speech_service.clear_rate_limit_cache()
    await _add_member(db_session, challenge, user)
    resp = await client.post(
        _speech_url(challenge.id),
        json={"content": "가" * 41},
        headers=_auth(user),
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "SPEECH_TOO_LONG"


@pytest.mark.asyncio
async def test_post_newline_stripped(client: AsyncClient, db_session: AsyncSession, user: User, challenge: Challenge):
    room_speech_service.clear_rate_limit_cache()
    await _add_member(db_session, challenge, user)
    resp = await client.post(
        _speech_url(challenge.id),
        json={"content": "안녕\n하세요"},
        headers=_auth(user),
    )
    assert resp.status_code == 200
    assert resp.json()["data"]["content"] == "안녕하세요"


@pytest.mark.asyncio
async def test_post_non_member(client: AsyncClient, db_session: AsyncSession, user: User, challenge: Challenge):
    room_speech_service.clear_rate_limit_cache()
    resp = await client.post(
        _speech_url(challenge.id),
        json={"content": "안녕!"},
        headers=_auth(user),
    )
    assert resp.status_code == 403
    assert resp.json()["error"]["code"] == "SPEECH_NOT_MEMBER"


@pytest.mark.asyncio
async def test_post_rate_limited(client: AsyncClient, db_session: AsyncSession, user: User, challenge: Challenge):
    room_speech_service.clear_rate_limit_cache()
    await _add_member(db_session, challenge, user)

    resp1 = await client.post(
        _speech_url(challenge.id),
        json={"content": "첫번째"},
        headers=_auth(user),
    )
    assert resp1.status_code == 200

    resp2 = await client.post(
        _speech_url(challenge.id),
        json={"content": "두번째"},
        headers=_auth(user),
    )
    assert resp2.status_code == 429
    assert resp2.json()["error"]["code"] == "SPEECH_RATE_LIMITED"


@pytest.mark.asyncio
async def test_post_upsert(client: AsyncClient, db_session: AsyncSession, user: User, challenge: Challenge):
    room_speech_service.clear_rate_limit_cache()
    await _add_member(db_session, challenge, user)

    await client.post(
        _speech_url(challenge.id),
        json={"content": "처음"},
        headers=_auth(user),
    )

    room_speech_service.clear_rate_limit_cache()
    resp = await client.post(
        _speech_url(challenge.id),
        json={"content": "업데이트"},
        headers=_auth(user),
    )
    assert resp.status_code == 200
    assert resp.json()["data"]["content"] == "업데이트"

    get_resp = await client.get(_speech_url(challenge.id), headers=_auth(user))
    items = get_resp.json()["data"]
    assert len(items) == 1
    assert items[0]["content"] == "업데이트"


@pytest.mark.asyncio
async def test_get_returns_list(
    client: AsyncClient, db_session: AsyncSession, user: User, other_user: User, challenge: Challenge
):
    room_speech_service.clear_rate_limit_cache()
    await _add_member(db_session, challenge, user)
    await _add_member(db_session, challenge, other_user)

    await client.post(_speech_url(challenge.id), json={"content": "유저1"}, headers=_auth(user))
    room_speech_service.clear_rate_limit_cache()
    await client.post(_speech_url(challenge.id), json={"content": "유저2"}, headers=_auth(other_user))

    resp = await client.get(_speech_url(challenge.id), headers=_auth(user))
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert isinstance(data, list)
    assert len(data) == 2
    for item in data:
        assert "user_id" in item
        assert "nickname" in item
        assert "content" in item
        assert "expires_at" in item


@pytest.mark.asyncio
async def test_get_excludes_expired(
    client: AsyncClient, db_session: AsyncSession, user: User, challenge: Challenge
):
    room_speech_service.clear_rate_limit_cache()
    await _add_member(db_session, challenge, user)
    await _insert_expired_speech(db_session, challenge, user)

    resp = await client.get(_speech_url(challenge.id), headers=_auth(user))
    assert resp.status_code == 200
    assert resp.json()["data"] == []


@pytest.mark.asyncio
async def test_get_non_member(client: AsyncClient, db_session: AsyncSession, user: User, challenge: Challenge):
    resp = await client.get(_speech_url(challenge.id), headers=_auth(user))
    assert resp.status_code == 403
    assert resp.json()["error"]["code"] == "SPEECH_NOT_MEMBER"


@pytest.mark.asyncio
async def test_delete_removes_row(client: AsyncClient, db_session: AsyncSession, user: User, challenge: Challenge):
    room_speech_service.clear_rate_limit_cache()
    await _add_member(db_session, challenge, user)
    await client.post(_speech_url(challenge.id), json={"content": "삭제대상"}, headers=_auth(user))

    resp = await client.delete(_speech_url(challenge.id), headers=_auth(user))
    assert resp.status_code == 200
    assert resp.json()["data"]["ok"] is True

    get_resp = await client.get(_speech_url(challenge.id), headers=_auth(user))
    assert get_resp.json()["data"] == []


@pytest.mark.asyncio
async def test_delete_idempotent(client: AsyncClient, db_session: AsyncSession, user: User, challenge: Challenge):
    room_speech_service.clear_rate_limit_cache()
    await _add_member(db_session, challenge, user)

    resp1 = await client.delete(_speech_url(challenge.id), headers=_auth(user))
    assert resp1.status_code == 200

    resp2 = await client.delete(_speech_url(challenge.id), headers=_auth(user))
    assert resp2.status_code == 200
    assert resp2.json()["data"]["ok"] is True
