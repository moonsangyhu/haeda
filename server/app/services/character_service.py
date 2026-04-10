import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.exceptions import AppException
from app.models.character_equip import CharacterEquip
from app.models.item import Item
from app.models.user_item import UserItem
from app.schemas.item import CharacterResponse, CharacterUpdateRequest, EquippedItemBrief

# maps slot field name to item category name
SLOT_TO_CATEGORY: dict[str, str] = {
    "hat_item_id": "HAT",
    "top_item_id": "TOP",
    "bottom_item_id": "BOTTOM",
    "shoes_item_id": "SHOES",
    "accessory_item_id": "ACCESSORY",
}


async def _fetch_item_brief(
    db: AsyncSession, item_id: uuid.UUID | None
) -> EquippedItemBrief | None:
    if item_id is None:
        return None
    result = await db.execute(select(Item).where(Item.id == item_id))
    item = result.scalar_one_or_none()
    if item is None:
        return None
    return EquippedItemBrief(
        id=item.id,
        name=item.name,
        category=item.category,
        rarity=item.rarity,
        asset_key=item.asset_key,
    )


async def get_character(db: AsyncSession, user_id: uuid.UUID) -> CharacterResponse:
    result = await db.execute(
        select(CharacterEquip).where(CharacterEquip.user_id == user_id)
    )
    equip = result.scalar_one_or_none()

    if equip is None:
        return CharacterResponse(
            hat=None,
            top=None,
            bottom=None,
            shoes=None,
            accessory=None,
        )

    hat = await _fetch_item_brief(db, equip.hat_item_id)
    top = await _fetch_item_brief(db, equip.top_item_id)
    bottom = await _fetch_item_brief(db, equip.bottom_item_id)
    shoes = await _fetch_item_brief(db, equip.shoes_item_id)
    accessory = await _fetch_item_brief(db, equip.accessory_item_id)

    return CharacterResponse(
        hat=hat,
        top=top,
        bottom=bottom,
        shoes=shoes,
        accessory=accessory,
    )


async def _validate_slot_item(
    db: AsyncSession,
    user_id: uuid.UUID,
    item_id: uuid.UUID | None,
    slot: str,
) -> None:
    if item_id is None:
        return

    expected_category = SLOT_TO_CATEGORY[slot]

    item_result = await db.execute(select(Item).where(Item.id == item_id))
    item = item_result.scalar_one_or_none()
    if item is None:
        raise AppException(
            status_code=404,
            code="ITEM_NOT_FOUND",
            message=f"아이템을 찾을 수 없습니다: {item_id}",
        )

    if item.category.upper() != expected_category:
        raise AppException(
            status_code=400,
            code="INVALID_CATEGORY",
            message=f"{slot} 슬롯에는 {expected_category} 카테고리 아이템만 장착할 수 있습니다.",
        )

    owned_result = await db.execute(
        select(UserItem).where(
            UserItem.user_id == user_id,
            UserItem.item_id == item_id,
        )
    )
    if owned_result.scalar_one_or_none() is None:
        raise AppException(
            status_code=403,
            code="ITEM_NOT_OWNED",
            message="보유하지 않은 아이템입니다.",
        )


async def update_character(
    db: AsyncSession,
    user_id: uuid.UUID,
    data: CharacterUpdateRequest,
) -> CharacterResponse:
    slots = {
        "hat_item_id": data.hat_item_id,
        "top_item_id": data.top_item_id,
        "bottom_item_id": data.bottom_item_id,
        "shoes_item_id": data.shoes_item_id,
        "accessory_item_id": data.accessory_item_id,
    }

    for slot, item_id in slots.items():
        if item_id is not None:
            await _validate_slot_item(db, user_id, item_id, slot)

    result = await db.execute(
        select(CharacterEquip).where(CharacterEquip.user_id == user_id)
    )
    equip = result.scalar_one_or_none()

    if equip is None:
        equip = CharacterEquip(user_id=user_id)
        db.add(equip)

    for slot, item_id in slots.items():
        if item_id is not None or slot in data.model_fields_set:
            setattr(equip, slot, item_id)

    await db.commit()
    await db.refresh(equip)

    return await get_character(db, user_id)
