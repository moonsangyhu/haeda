"""Gem pack catalog + purchase 테스트"""
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.exceptions import AppException
from app.models.user import User
from app.services import gem_pack_service


@pytest.mark.asyncio
async def test_purchase_small_pack_awards_1000_gems(
    db_session: AsyncSession, user: User
):
    result = await gem_pack_service.purchase(db_session, user.id, "pack_small")
    await db_session.commit()
    assert result.awarded_gems == 1000
    assert result.balance == 1000
    assert result.pack_id == "pack_small"


@pytest.mark.asyncio
async def test_purchase_medium_includes_bonus(
    db_session: AsyncSession, user: User
):
    result = await gem_pack_service.purchase(db_session, user.id, "pack_medium")
    await db_session.commit()
    assert result.awarded_gems == 5500  # 5000 + 500 bonus
    assert result.balance == 5500


@pytest.mark.asyncio
async def test_purchase_unknown_pack_raises(
    db_session: AsyncSession, user: User
):
    with pytest.raises(AppException) as exc:
        await gem_pack_service.purchase(db_session, user.id, "pack_invalid")
    assert exc.value.code == "PACK_NOT_FOUND"
    assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_packs_endpoint_returns_3_tiers(
    client: AsyncClient, user: User
):
    resp = await client.get(
        "/api/v1/gems/packs",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 200
    packs = resp.json()["data"]["packs"]
    assert len(packs) == 3
    ids = [p["id"] for p in packs]
    assert ids == ["pack_small", "pack_medium", "pack_large"]
    pack_med = next(p for p in packs if p["id"] == "pack_medium")
    assert pack_med["gems"] == 5000
    assert pack_med["bonus_gems"] == 500
    assert pack_med["price_krw"] == 25000


@pytest.mark.asyncio
async def test_purchase_endpoint_unknown_pack_returns_404(
    client: AsyncClient, user: User
):
    resp = await client.post(
        "/api/v1/gems/packs/pack_invalid/purchase",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 404
    assert resp.json()["error"]["code"] == "PACK_NOT_FOUND"


@pytest.mark.asyncio
async def test_purchase_endpoint_small_pack_awards_balance(
    client: AsyncClient, user: User
):
    resp = await client.post(
        "/api/v1/gems/packs/pack_small/purchase",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["awarded_gems"] == 1000
    assert data["balance"] == 1000
    assert data["pack_id"] == "pack_small"


@pytest.mark.asyncio
async def test_purchase_endpoint_no_token_returns_401(client: AsyncClient):
    resp = await client.post("/api/v1/gems/packs/pack_small/purchase")
    assert resp.status_code == 401
