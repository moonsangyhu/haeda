from datetime import datetime
from enum import Enum

from pydantic import BaseModel


class ChestState(str, Enum):
    NO_CHEST = "no_chest"
    LOCKED = "locked"
    OPENABLE = "openable"
    OPENED = "opened"


class TreasureChestResponse(BaseModel):
    state: ChestState
    armed_at: datetime | None
    openable_at: datetime | None
    opened_at: datetime | None
    reward_gems: int
    remaining_seconds: int | None


class OpenChestResponse(BaseModel):
    reward_gems: int
    balance: int
    opened_at: datetime
