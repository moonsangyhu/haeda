import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.character_equip import CharacterEquip
from app.models.item import Item
from app.schemas.character_schema import CharacterSlotBrief, MemberCharacter


async def load_member_characters(
    db: AsyncSession,
    user_ids: list[uuid.UUID],
) -> dict[uuid.UUID, MemberCharacter]:
    """Batch-load character equipment for multiple users.

    Returns a dict mapping user_id -> MemberCharacter.
    Users without equipment get a MemberCharacter with all None slots.
    """
    if not user_ids:
        return {}

    # 1. CharacterEquip for all users
    equip_stmt = select(CharacterEquip).where(CharacterEquip.user_id.in_(user_ids))
    equip_result = await db.execute(equip_stmt)
    equip_map: dict[uuid.UUID, CharacterEquip] = {
        e.user_id: e for e in equip_result.scalars().all()
    }

    # 2. Collect all equipped item IDs
    item_ids: set[uuid.UUID] = set()
    for eq in equip_map.values():
        for slot in [eq.hat_item_id, eq.top_item_id, eq.bottom_item_id, eq.shoes_item_id, eq.accessory_item_id]:
            if slot:
                item_ids.add(slot)

    # 3. Batch-load items
    item_map: dict[uuid.UUID, Item] = {}
    if item_ids:
        item_stmt = select(Item).where(Item.id.in_(item_ids))
        item_result = await db.execute(item_stmt)
        item_map = {i.id: i for i in item_result.scalars().all()}

    def _slot(item_id: uuid.UUID | None) -> CharacterSlotBrief | None:
        if item_id and item_id in item_map:
            it = item_map[item_id]
            return CharacterSlotBrief(asset_key=it.asset_key, rarity=it.rarity)
        return None

    # 4. Build result dict
    result: dict[uuid.UUID, MemberCharacter] = {}
    for uid in user_ids:
        eq = equip_map.get(uid)
        result[uid] = MemberCharacter(
            hat=_slot(eq.hat_item_id) if eq else None,
            top=_slot(eq.top_item_id) if eq else None,
            bottom=_slot(eq.bottom_item_id) if eq else None,
            shoes=_slot(eq.shoes_item_id) if eq else None,
            accessory=_slot(eq.accessory_item_id) if eq else None,
        )
    return result
