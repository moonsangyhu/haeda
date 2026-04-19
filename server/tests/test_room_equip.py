"""Tests for Room Decoration endpoints (Phase 1 backend)."""
import uuid

import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.challenge import Challenge
from app.models.challenge_member import ChallengeMember
from app.models.item import Item
from app.models.user import User
from app.models.user_item import UserItem


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _auth(user: User) -> dict:
    return {"Authorization": f"Bearer {user.id}"}


async def _make_item(
    db: AsyncSession,
    category: str,
    name: str = None,
    price: int = 0,
) -> Item:
    item = Item(
        id=uuid.uuid4(),
        name=name or f"{category} 테스트",
        category=category,
        price=price,
        rarity="COMMON",
        asset_key=f"test/{category.lower()}_{uuid.uuid4().hex[:6]}",
        is_active=True,
        is_limited=False,
        reward_trigger="SHOP",
        sort_order=0,
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item


async def _give_item(db: AsyncSession, user: User, item: Item) -> UserItem:
    ui = UserItem(id=uuid.uuid4(), user_id=user.id, item_id=item.id)
    db.add(ui)
    await db.commit()
    return ui


async def _add_member(db: AsyncSession, challenge: Challenge, user: User) -> ChallengeMember:
    m = ChallengeMember(id=uuid.uuid4(), challenge_id=challenge.id, user_id=user.id)
    db.add(m)
    await db.commit()
    return m


# ---------------------------------------------------------------------------
# Mini-room tests
# ---------------------------------------------------------------------------

class TestGetMiniroom:
    @pytest.mark.asyncio
    async def test_empty_get_returns_all_null(
        self, client: AsyncClient, user: User
    ):
        resp = await client.get("/api/v1/me/room/miniroom", headers=_auth(user))
        assert resp.status_code == 200
        data = resp.json()["data"]
        for slot in ("wall", "ceiling", "window", "shelf", "plant", "desk", "rug", "floor"):
            assert data[slot] is None

    @pytest.mark.asyncio
    async def test_unauthorized_returns_401(self, client: AsyncClient):
        resp = await client.get("/api/v1/me/room/miniroom")
        assert resp.status_code == 401


class TestUpdateMiniroom:
    @pytest.mark.asyncio
    async def test_put_owned_item_happy_path(
        self, client: AsyncClient, db_session: AsyncSession, user: User
    ):
        item = await _make_item(db_session, "MR_WALL")
        await _give_item(db_session, user, item)

        resp = await client.put(
            "/api/v1/me/room/miniroom",
            json={"wall_item_id": str(item.id)},
            headers=_auth(user),
        )
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["wall"] is not None
        assert data["wall"]["id"] == str(item.id)
        assert data["wall"]["category"] == "MR_WALL"

    @pytest.mark.asyncio
    async def test_put_unowned_item_returns_403(
        self, client: AsyncClient, db_session: AsyncSession, user: User
    ):
        item = await _make_item(db_session, "MR_WALL")
        # NOT giving the item to user

        resp = await client.put(
            "/api/v1/me/room/miniroom",
            json={"wall_item_id": str(item.id)},
            headers=_auth(user),
        )
        assert resp.status_code == 403
        assert resp.json()["error"]["code"] == "ITEM_NOT_OWNED"

    @pytest.mark.asyncio
    async def test_put_wrong_category_returns_422(
        self, client: AsyncClient, db_session: AsyncSession, user: User
    ):
        item = await _make_item(db_session, "MR_CEILING")
        await _give_item(db_session, user, item)

        resp = await client.put(
            "/api/v1/me/room/miniroom",
            json={"wall_item_id": str(item.id)},  # wall slot but ceiling category
            headers=_auth(user),
        )
        assert resp.status_code == 422
        assert resp.json()["error"]["code"] == "ITEM_CATEGORY_MISMATCH"

    @pytest.mark.asyncio
    async def test_put_multiple_slots_partial_update(
        self, client: AsyncClient, db_session: AsyncSession, user: User
    ):
        wall_item = await _make_item(db_session, "MR_WALL")
        floor_item = await _make_item(db_session, "MR_FLOOR")
        await _give_item(db_session, user, wall_item)
        await _give_item(db_session, user, floor_item)

        resp = await client.put(
            "/api/v1/me/room/miniroom",
            json={
                "wall_item_id": str(wall_item.id),
                "floor_item_id": str(floor_item.id),
            },
            headers=_auth(user),
        )
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["wall"]["id"] == str(wall_item.id)
        assert data["floor"]["id"] == str(floor_item.id)
        assert data["ceiling"] is None


class TestDeleteMiniroomSlot:
    @pytest.mark.asyncio
    async def test_delete_slot_returns_null(
        self, client: AsyncClient, db_session: AsyncSession, user: User
    ):
        item = await _make_item(db_session, "MR_WALL")
        await _give_item(db_session, user, item)
        # First equip
        await client.put(
            "/api/v1/me/room/miniroom",
            json={"wall_item_id": str(item.id)},
            headers=_auth(user),
        )
        # Then delete
        resp = await client.delete(
            "/api/v1/me/room/miniroom/wall",
            headers=_auth(user),
        )
        assert resp.status_code == 200
        assert resp.json()["data"]["wall"] is None

    @pytest.mark.asyncio
    async def test_delete_invalid_slot_returns_422(
        self, client: AsyncClient, user: User
    ):
        resp = await client.delete(
            "/api/v1/me/room/miniroom/invalid_slot",
            headers=_auth(user),
        )
        assert resp.status_code == 422
        assert resp.json()["error"]["code"] == "INVALID_SLOT"


# ---------------------------------------------------------------------------
# Challenge room tests
# ---------------------------------------------------------------------------

class TestGetChallengeRoom:
    @pytest.mark.asyncio
    async def test_get_empty_challenge_room(
        self, client: AsyncClient, user: User, challenge: Challenge
    ):
        resp = await client.get(
            f"/api/v1/challenges/{challenge.id}/room",
            headers=_auth(user),
        )
        assert resp.status_code == 200
        data = resp.json()["data"]
        for slot in ("wall", "window", "calendar", "board", "sofa", "floor"):
            assert data[slot] is None
        assert data["signatures"] == []

    @pytest.mark.asyncio
    async def test_non_member_can_read(
        self, client: AsyncClient, other_user: User, challenge: Challenge
    ):
        """GET /challenges/{id}/room is publicly readable for authenticated users."""
        resp = await client.get(
            f"/api/v1/challenges/{challenge.id}/room",
            headers=_auth(other_user),
        )
        assert resp.status_code == 200


class TestUpdateChallengeRoom:
    @pytest.mark.asyncio
    async def test_creator_put_owned_item_happy_path(
        self, client: AsyncClient, db_session: AsyncSession, user: User, challenge: Challenge
    ):
        item = await _make_item(db_session, "CR_WALL")
        await _give_item(db_session, user, item)

        resp = await client.put(
            f"/api/v1/challenges/{challenge.id}/room",
            json={"wall_item_id": str(item.id)},
            headers=_auth(user),
        )
        assert resp.status_code == 200
        data = resp.json()["data"]
        assert data["wall"]["id"] == str(item.id)
        assert data["updated_by_user_id"] == str(user.id)

    @pytest.mark.asyncio
    async def test_non_creator_put_returns_403(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
        other_user: User,
        challenge: Challenge,
    ):
        item = await _make_item(db_session, "CR_WALL")
        await _give_item(db_session, other_user, item)

        resp = await client.put(
            f"/api/v1/challenges/{challenge.id}/room",
            json={"wall_item_id": str(item.id)},
            headers=_auth(other_user),
        )
        assert resp.status_code == 403
        assert resp.json()["error"]["code"] == "CR_NOT_CREATOR"


class TestDeleteChallengeRoomSlot:
    @pytest.mark.asyncio
    async def test_creator_delete_slot(
        self, client: AsyncClient, db_session: AsyncSession, user: User, challenge: Challenge
    ):
        item = await _make_item(db_session, "CR_WALL")
        await _give_item(db_session, user, item)
        await client.put(
            f"/api/v1/challenges/{challenge.id}/room",
            json={"wall_item_id": str(item.id)},
            headers=_auth(user),
        )

        resp = await client.delete(
            f"/api/v1/challenges/{challenge.id}/room/wall",
            headers=_auth(user),
        )
        assert resp.status_code == 200
        assert resp.json()["data"]["wall"] is None

    @pytest.mark.asyncio
    async def test_invalid_slot_returns_422(
        self, client: AsyncClient, user: User, challenge: Challenge
    ):
        resp = await client.delete(
            f"/api/v1/challenges/{challenge.id}/room/bad_slot",
            headers=_auth(user),
        )
        assert resp.status_code == 422
        assert resp.json()["error"]["code"] == "INVALID_SLOT"


# ---------------------------------------------------------------------------
# Signature tests
# ---------------------------------------------------------------------------

class TestSignature:
    @pytest.mark.asyncio
    async def test_member_set_signature_happy_path(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
        user: User,
        challenge: Challenge,
    ):
        await _add_member(db_session, challenge, user)
        item = await _make_item(db_session, "SIGNATURE")
        await _give_item(db_session, user, item)

        resp = await client.put(
            f"/api/v1/challenges/{challenge.id}/room/signature",
            json={"signature_item_id": str(item.id)},
            headers=_auth(user),
        )
        assert resp.status_code == 200
        sigs = resp.json()["data"]["signatures"]
        assert len(sigs) == 1
        assert sigs[0]["user_id"] == str(user.id)
        assert sigs[0]["signature_item"]["id"] == str(item.id)

    @pytest.mark.asyncio
    async def test_non_member_set_signature_returns_403(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
        other_user: User,
        challenge: Challenge,
    ):
        item = await _make_item(db_session, "SIGNATURE")
        await _give_item(db_session, other_user, item)

        resp = await client.put(
            f"/api/v1/challenges/{challenge.id}/room/signature",
            json={"signature_item_id": str(item.id)},
            headers=_auth(other_user),
        )
        assert resp.status_code == 403
        assert resp.json()["error"]["code"] == "CR_NOT_MEMBER"

    @pytest.mark.asyncio
    async def test_signature_wrong_category_returns_422(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
        user: User,
        challenge: Challenge,
    ):
        await _add_member(db_session, challenge, user)
        item = await _make_item(db_session, "MR_WALL")  # wrong category
        await _give_item(db_session, user, item)

        resp = await client.put(
            f"/api/v1/challenges/{challenge.id}/room/signature",
            json={"signature_item_id": str(item.id)},
            headers=_auth(user),
        )
        assert resp.status_code == 422
        assert resp.json()["error"]["code"] == "ITEM_CATEGORY_MISMATCH"

    @pytest.mark.asyncio
    async def test_member_clear_signature(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
        user: User,
        challenge: Challenge,
    ):
        await _add_member(db_session, challenge, user)
        item = await _make_item(db_session, "SIGNATURE")
        await _give_item(db_session, user, item)

        # Set first
        await client.put(
            f"/api/v1/challenges/{challenge.id}/room/signature",
            json={"signature_item_id": str(item.id)},
            headers=_auth(user),
        )
        # Clear
        resp = await client.delete(
            f"/api/v1/challenges/{challenge.id}/room/signature",
            headers=_auth(user),
        )
        assert resp.status_code == 200
        sigs = resp.json()["data"]["signatures"]
        assert len(sigs) == 0

    @pytest.mark.asyncio
    async def test_non_member_clear_signature_returns_403(
        self,
        client: AsyncClient,
        other_user: User,
        challenge: Challenge,
    ):
        resp = await client.delete(
            f"/api/v1/challenges/{challenge.id}/room/signature",
            headers=_auth(other_user),
        )
        assert resp.status_code == 403
        assert resp.json()["error"]["code"] == "CR_NOT_MEMBER"

    @pytest.mark.asyncio
    async def test_signature_unowned_item_returns_403(
        self,
        client: AsyncClient,
        db_session: AsyncSession,
        user: User,
        challenge: Challenge,
    ):
        await _add_member(db_session, challenge, user)
        item = await _make_item(db_session, "SIGNATURE")
        # NOT giving item to user

        resp = await client.put(
            f"/api/v1/challenges/{challenge.id}/room/signature",
            json={"signature_item_id": str(item.id)},
            headers=_auth(user),
        )
        assert resp.status_code == 403
        assert resp.json()["error"]["code"] == "ITEM_NOT_OWNED"
