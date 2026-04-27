"""Treasure chest service + endpoint 테스트"""
import uuid
from datetime import date, datetime, timedelta, timezone
from unittest.mock import patch

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.challenge import Challenge
from app.models.challenge_member import ChallengeMember
from app.models.gem_transaction import GemTransaction
from app.models.user import User
from app.models.user_treasure_state import UserTreasureState
from app.models.verification import Verification
from app.schemas.treasure_chest import ChestState
from app.services import treasure_chest_service


def _now() -> datetime:
    return datetime(2026, 4, 27, 18, 0, 0, tzinfo=timezone.utc)


@pytest.mark.asyncio
async def test_no_state_returns_no_chest(
    db_session: AsyncSession, user: User
):
    """DB 행 없는 신규 유저: state=no_chest, 모든 필드 null."""
    with patch("app.services.treasure_chest_service._now", return_value=_now()):
        result = await treasure_chest_service.get_state(db_session, user.id)
    assert result.state == ChestState.NO_CHEST
    assert result.armed_at is None
    assert result.openable_at is None
    assert result.opened_at is None
    assert result.reward_gems == 100
    assert result.remaining_seconds is None


@pytest.mark.asyncio
async def test_armed_today_locked(
    db_session: AsyncSession, user: User
):
    """armed_at = now-5h, opened=false → state=locked, remaining ≈ 7h."""
    now = _now()
    db_session.add(
        UserTreasureState(
            user_id=user.id,
            armed_date=now.date(),
            armed_at=now - timedelta(hours=5),
            opened=False,
        )
    )
    await db_session.commit()
    with patch("app.services.treasure_chest_service._now", return_value=now):
        result = await treasure_chest_service.get_state(db_session, user.id)
    assert result.state == ChestState.LOCKED
    assert result.remaining_seconds is not None
    assert 6 * 3600 < result.remaining_seconds <= 7 * 3600


@pytest.mark.asyncio
async def test_armed_today_openable(
    db_session: AsyncSession, user: User
):
    """armed_at = now-13h, opened=false → state=openable."""
    now = _now()
    db_session.add(
        UserTreasureState(
            user_id=user.id,
            armed_date=now.date(),
            armed_at=now - timedelta(hours=13),
            opened=False,
        )
    )
    await db_session.commit()
    with patch("app.services.treasure_chest_service._now", return_value=now):
        result = await treasure_chest_service.get_state(db_session, user.id)
    assert result.state == ChestState.OPENABLE
    assert result.remaining_seconds == 0


@pytest.mark.asyncio
async def test_opened_today(
    db_session: AsyncSession, user: User
):
    """opened=true, today → state=opened."""
    now = _now()
    db_session.add(
        UserTreasureState(
            user_id=user.id,
            armed_date=now.date(),
            armed_at=now - timedelta(hours=14),
            opened=True,
        )
    )
    await db_session.commit()
    with patch("app.services.treasure_chest_service._now", return_value=now):
        result = await treasure_chest_service.get_state(db_session, user.id)
    assert result.state == ChestState.OPENED


@pytest.mark.asyncio
async def test_armed_yesterday_returns_no_chest(
    db_session: AsyncSession, user: User
):
    """armed_date=yesterday → state=no_chest (어제 chest 만료)."""
    now = _now()
    db_session.add(
        UserTreasureState(
            user_id=user.id,
            armed_date=now.date() - timedelta(days=1),
            armed_at=now - timedelta(hours=20),
            opened=False,
        )
    )
    await db_session.commit()
    with patch("app.services.treasure_chest_service._now", return_value=now):
        result = await treasure_chest_service.get_state(db_session, user.id)
    assert result.state == ChestState.NO_CHEST


@pytest.mark.asyncio
async def test_arm_if_first_today_inserts_row(
    db_session: AsyncSession, user: User
):
    """행 없음 + 호출 → INSERT, armed_date=today, opened=false."""
    now = _now()
    await treasure_chest_service.arm_if_first_today(db_session, user.id, now)
    await db_session.commit()
    stmt = select(UserTreasureState).where(UserTreasureState.user_id == user.id)
    result = await db_session.execute(stmt)
    row = result.scalar_one()
    assert row.armed_date == now.date()
    armed_at = row.armed_at if row.armed_at.tzinfo else row.armed_at.replace(tzinfo=timezone.utc)
    assert armed_at == now
    assert row.opened is False


@pytest.mark.asyncio
async def test_arm_if_first_today_idempotent_same_day(
    db_session: AsyncSession, user: User
):
    """같은 날 재호출 → no-op (armed_at, opened 변화 없음)."""
    now = _now()
    original = now - timedelta(hours=3)
    db_session.add(
        UserTreasureState(
            user_id=user.id,
            armed_date=now.date(),
            armed_at=original,
            opened=False,
        )
    )
    await db_session.commit()

    await treasure_chest_service.arm_if_first_today(db_session, user.id, now)
    await db_session.commit()

    stmt = select(UserTreasureState).where(UserTreasureState.user_id == user.id)
    result = await db_session.execute(stmt)
    row = result.scalar_one()
    armed_at = row.armed_at if row.armed_at.tzinfo else row.armed_at.replace(tzinfo=timezone.utc)
    assert armed_at == original
    assert row.opened is False


@pytest.mark.asyncio
async def test_arm_if_first_today_resets_after_day_change(
    db_session: AsyncSession, user: User
):
    """armed_date=어제 + opened=true → UPDATE today, opened=false."""
    now = _now()
    db_session.add(
        UserTreasureState(
            user_id=user.id,
            armed_date=now.date() - timedelta(days=1),
            armed_at=now - timedelta(hours=20),
            opened=True,
        )
    )
    await db_session.commit()

    await treasure_chest_service.arm_if_first_today(db_session, user.id, now)
    await db_session.commit()

    stmt = select(UserTreasureState).where(UserTreasureState.user_id == user.id)
    result = await db_session.execute(stmt)
    row = result.scalar_one()
    assert row.armed_date == now.date()
    armed_at = row.armed_at if row.armed_at.tzinfo else row.armed_at.replace(tzinfo=timezone.utc)
    assert armed_at == now
    assert row.opened is False


@pytest.mark.asyncio
async def test_open_chest_openable_awards_gems(
    db_session: AsyncSession, user: User
):
    """openable 상태에서 open_chest → balance += 100, opened=true."""
    now = _now()
    db_session.add(
        UserTreasureState(
            user_id=user.id,
            armed_date=now.date(),
            armed_at=now - timedelta(hours=13),
            opened=False,
        )
    )
    await db_session.commit()

    with patch("app.services.treasure_chest_service._now", return_value=now):
        result = await treasure_chest_service.open_chest(db_session, user.id)
    await db_session.commit()

    assert result.reward_gems == 100
    assert result.balance == 100

    from sqlalchemy import func, select as sql_select
    bal_stmt = sql_select(func.coalesce(func.sum(GemTransaction.amount), 0)).where(
        GemTransaction.user_id == user.id
    )
    bal_result = await db_session.execute(bal_stmt)
    assert bal_result.scalar_one() == 100

    stmt = select(UserTreasureState).where(UserTreasureState.user_id == user.id)
    row_result = await db_session.execute(stmt)
    assert row_result.scalar_one().opened is True


@pytest.mark.asyncio
async def test_open_chest_locked_raises(
    db_session: AsyncSession, user: User
):
    """locked 상태에서 open_chest → AppException CHEST_NOT_READY."""
    from app.exceptions import AppException

    now = _now()
    db_session.add(
        UserTreasureState(
            user_id=user.id,
            armed_date=now.date(),
            armed_at=now - timedelta(hours=5),
            opened=False,
        )
    )
    await db_session.commit()

    with patch("app.services.treasure_chest_service._now", return_value=now):
        with pytest.raises(AppException) as exc:
            await treasure_chest_service.open_chest(db_session, user.id)
    assert exc.value.code == "CHEST_NOT_READY"
    assert exc.value.status_code == 409


@pytest.mark.asyncio
async def test_open_chest_already_opened_raises(
    db_session: AsyncSession, user: User
):
    """opened=true 상태에서 open_chest → AppException CHEST_ALREADY_OPENED."""
    from app.exceptions import AppException

    now = _now()
    db_session.add(
        UserTreasureState(
            user_id=user.id,
            armed_date=now.date(),
            armed_at=now - timedelta(hours=14),
            opened=True,
        )
    )
    await db_session.commit()

    with patch("app.services.treasure_chest_service._now", return_value=now):
        with pytest.raises(AppException) as exc:
            await treasure_chest_service.open_chest(db_session, user.id)
    assert exc.value.code == "CHEST_ALREADY_OPENED"
    assert exc.value.status_code == 409


@pytest.mark.asyncio
async def test_open_chest_no_chest_raises(
    db_session: AsyncSession, user: User
):
    """no_chest 상태에서 open_chest → AppException CHEST_NOT_READY."""
    from app.exceptions import AppException

    with patch("app.services.treasure_chest_service._now", return_value=_now()):
        with pytest.raises(AppException) as exc:
            await treasure_chest_service.open_chest(db_session, user.id)
    assert exc.value.code == "CHEST_NOT_READY"
    assert exc.value.status_code == 409


@pytest.mark.asyncio
async def test_chest_endpoint_returns_no_chest_for_new_user(
    client: AsyncClient, user: User
):
    resp = await client.get(
        "/api/v1/gems/chest",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["state"] == "no_chest"
    assert data["reward_gems"] == 100


@pytest.mark.asyncio
async def test_chest_endpoint_no_token_returns_401(client: AsyncClient):
    resp = await client.get("/api/v1/gems/chest")
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_open_endpoint_locked_returns_409(
    client: AsyncClient, db_session: AsyncSession, user: User
):
    now = _now()
    db_session.add(
        UserTreasureState(
            user_id=user.id,
            armed_date=now.date(),
            armed_at=now - timedelta(hours=5),
            opened=False,
        )
    )
    await db_session.commit()
    with patch("app.services.treasure_chest_service._now", return_value=now):
        resp = await client.post(
            "/api/v1/gems/chest/open",
            headers={"Authorization": f"Bearer {user.id}"},
        )
    assert resp.status_code == 409
    assert resp.json()["error"]["code"] == "CHEST_NOT_READY"


@pytest.mark.asyncio
async def test_open_endpoint_openable_returns_200(
    client: AsyncClient, db_session: AsyncSession, user: User
):
    now = _now()
    db_session.add(
        UserTreasureState(
            user_id=user.id,
            armed_date=now.date(),
            armed_at=now - timedelta(hours=13),
            opened=False,
        )
    )
    await db_session.commit()
    with patch("app.services.treasure_chest_service._now", return_value=now):
        resp = await client.post(
            "/api/v1/gems/chest/open",
            headers={"Authorization": f"Bearer {user.id}"},
        )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["reward_gems"] == 100
    assert data["balance"] == 100
