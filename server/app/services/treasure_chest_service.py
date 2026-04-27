import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user_treasure_state import UserTreasureState
from app.schemas.treasure_chest import (
    ChestState,
    OpenChestResponse,
    TreasureChestResponse,
)

CHEST_REWARD_GEMS = 100
CHEST_TIMER_HOURS = 12


def _now() -> datetime:
    return datetime.now(timezone.utc)


async def get_state(
    db: AsyncSession, user_id: uuid.UUID
) -> TreasureChestResponse:
    now = _now()
    today = now.date()

    stmt = select(UserTreasureState).where(UserTreasureState.user_id == user_id)
    result = await db.execute(stmt)
    row = result.scalar_one_or_none()

    if row is None or row.armed_date != today:
        return TreasureChestResponse(
            state=ChestState.NO_CHEST,
            armed_at=None,
            openable_at=None,
            opened_at=None,
            reward_gems=CHEST_REWARD_GEMS,
            remaining_seconds=None,
        )

    armed_at = row.armed_at
    if armed_at.tzinfo is None:
        armed_at = armed_at.replace(tzinfo=timezone.utc)
    openable_at = armed_at + timedelta(hours=CHEST_TIMER_HOURS)

    if row.opened:
        opened_at = row.updated_at
        if opened_at is not None and opened_at.tzinfo is None:
            opened_at = opened_at.replace(tzinfo=timezone.utc)
        return TreasureChestResponse(
            state=ChestState.OPENED,
            armed_at=armed_at,
            openable_at=openable_at,
            opened_at=opened_at,
            reward_gems=CHEST_REWARD_GEMS,
            remaining_seconds=None,
        )

    if now < openable_at:
        remaining = int((openable_at - now).total_seconds())
        return TreasureChestResponse(
            state=ChestState.LOCKED,
            armed_at=armed_at,
            openable_at=openable_at,
            opened_at=None,
            reward_gems=CHEST_REWARD_GEMS,
            remaining_seconds=remaining,
        )

    return TreasureChestResponse(
        state=ChestState.OPENABLE,
        armed_at=armed_at,
        openable_at=openable_at,
        opened_at=None,
        reward_gems=CHEST_REWARD_GEMS,
        remaining_seconds=0,
    )
