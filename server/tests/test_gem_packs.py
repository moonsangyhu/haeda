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
