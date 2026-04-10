import uuid
from datetime import datetime

from pydantic import BaseModel


class ShopItemResponse(BaseModel):
    id: uuid.UUID
    name: str
    category: str
    price: int
    rarity: str
    asset_key: str
    sort_order: int
    is_owned: bool
    effect_type: str | None = None
    effect_value: int | None = None

    model_config = {"from_attributes": True}


class UserItemResponse(BaseModel):
    id: uuid.UUID
    item_id: uuid.UUID
    name: str
    category: str
    rarity: str
    asset_key: str
    purchased_at: datetime

    model_config = {"from_attributes": True}


class EquippedItemBrief(BaseModel):
    id: uuid.UUID
    name: str
    category: str
    rarity: str
    asset_key: str

    model_config = {"from_attributes": True}


class CharacterResponse(BaseModel):
    hat: EquippedItemBrief | None
    top: EquippedItemBrief | None
    bottom: EquippedItemBrief | None
    shoes: EquippedItemBrief | None
    accessory: EquippedItemBrief | None
    skin_tone: str = "fair"
    eye_style: str = "round"
    hair_style: str = "short"

    model_config = {"from_attributes": True}


class CharacterUpdateRequest(BaseModel):
    hat_item_id: uuid.UUID | None = None
    top_item_id: uuid.UUID | None = None
    bottom_item_id: uuid.UUID | None = None
    shoes_item_id: uuid.UUID | None = None
    accessory_item_id: uuid.UUID | None = None


VALID_SKIN_TONES = {"light", "fair", "dark"}
VALID_EYE_STYLES = {"round", "sharp", "sleepy"}
VALID_HAIR_STYLES = {"short", "long", "curly"}


class AppearanceUpdateRequest(BaseModel):
    skin_tone: str
    eye_style: str
    hair_style: str
