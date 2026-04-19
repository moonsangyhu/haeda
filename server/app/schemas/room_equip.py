import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel

from app.schemas.item import EquippedItemBrief


# ---------------------------------------------------------------------------
# Response schemas
# ---------------------------------------------------------------------------

class RoomEquipMrResponse(BaseModel):
    wall: EquippedItemBrief | None = None
    ceiling: EquippedItemBrief | None = None
    window: EquippedItemBrief | None = None
    shelf: EquippedItemBrief | None = None
    plant: EquippedItemBrief | None = None
    desk: EquippedItemBrief | None = None
    rug: EquippedItemBrief | None = None
    floor: EquippedItemBrief | None = None
    updated_at: datetime | None = None

    model_config = {"from_attributes": True}


class SignatureBrief(BaseModel):
    user_id: uuid.UUID
    nickname: str
    signature_item: EquippedItemBrief | None = None

    model_config = {"from_attributes": True}


class RoomEquipCrResponse(BaseModel):
    wall: EquippedItemBrief | None = None
    window: EquippedItemBrief | None = None
    calendar: EquippedItemBrief | None = None
    board: EquippedItemBrief | None = None
    sofa: EquippedItemBrief | None = None
    floor: EquippedItemBrief | None = None
    signatures: list[SignatureBrief] = []
    updated_by_user_id: uuid.UUID | None = None
    updated_at: datetime | None = None

    model_config = {"from_attributes": True}


# ---------------------------------------------------------------------------
# Request schemas
# ---------------------------------------------------------------------------

class RoomEquipMrUpdateRequest(BaseModel):
    wall_item_id: Optional[uuid.UUID] = None
    ceiling_item_id: Optional[uuid.UUID] = None
    window_item_id: Optional[uuid.UUID] = None
    shelf_item_id: Optional[uuid.UUID] = None
    plant_item_id: Optional[uuid.UUID] = None
    desk_item_id: Optional[uuid.UUID] = None
    rug_item_id: Optional[uuid.UUID] = None
    floor_item_id: Optional[uuid.UUID] = None

    model_config = {"extra": "forbid"}


class RoomEquipCrUpdateRequest(BaseModel):
    wall_item_id: Optional[uuid.UUID] = None
    window_item_id: Optional[uuid.UUID] = None
    calendar_item_id: Optional[uuid.UUID] = None
    board_item_id: Optional[uuid.UUID] = None
    sofa_item_id: Optional[uuid.UUID] = None
    floor_item_id: Optional[uuid.UUID] = None

    model_config = {"extra": "forbid"}


class SignatureUpdateRequest(BaseModel):
    signature_item_id: uuid.UUID
