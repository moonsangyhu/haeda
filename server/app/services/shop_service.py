import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.exceptions import AppException
from app.models.item import Item
from app.models.user_item import UserItem
from app.schemas.item import ShopItemResponse, UserItemResponse
from app.services import gem_service


async def list_items(
    db: AsyncSession,
    user_id: uuid.UUID,
    category: str | None = None,
) -> list[ShopItemResponse]:
    stmt = select(Item).where(Item.is_active.is_(True))
    if category:
        stmt = stmt.where(Item.category == category)
    stmt = stmt.order_by(Item.sort_order, Item.price)

    result = await db.execute(stmt)
    items = result.scalars().all()

    owned_stmt = select(UserItem.item_id).where(UserItem.user_id == user_id)
    owned_result = await db.execute(owned_stmt)
    owned_ids = {row[0] for row in owned_result.all()}

    return [
        ShopItemResponse(
            id=item.id,
            name=item.name,
            category=item.category,
            price=item.price,
            rarity=item.rarity,
            asset_key=item.asset_key,
            sort_order=item.sort_order,
            is_owned=item.id in owned_ids,
        )
        for item in items
    ]


async def purchase_item(
    db: AsyncSession,
    user_id: uuid.UUID,
    item_id: uuid.UUID,
) -> UserItemResponse:
    item_stmt = select(Item).where(Item.id == item_id, Item.is_active.is_(True))
    item_result = await db.execute(item_stmt)
    item = item_result.scalar_one_or_none()
    if item is None:
        raise AppException(
            status_code=404,
            code="ITEM_NOT_FOUND",
            message="아이템을 찾을 수 없습니다.",
        )

    owned_stmt = select(UserItem).where(
        UserItem.user_id == user_id,
        UserItem.item_id == item_id,
    )
    owned_result = await db.execute(owned_stmt)
    if owned_result.scalar_one_or_none() is not None:
        raise AppException(
            status_code=409,
            code="ALREADY_OWNED",
            message="이미 보유한 아이템입니다.",
        )

    balance = await gem_service.get_balance(db, user_id)
    if balance < item.price:
        raise AppException(
            status_code=402,
            code="INSUFFICIENT_COINS",
            message="코인이 부족합니다.",
        )

    await gem_service.award_gems(
        db=db,
        user_id=user_id,
        amount=-item.price,
        reason="PURCHASE",
        reference_id=item_id,
    )

    user_item = UserItem(
        id=uuid.uuid4(),
        user_id=user_id,
        item_id=item_id,
    )
    db.add(user_item)
    await db.flush()
    await db.commit()
    await db.refresh(user_item)

    return UserItemResponse(
        id=user_item.id,
        item_id=item.id,
        name=item.name,
        category=item.category,
        price=item.price,
        rarity=item.rarity,
        asset_key=item.asset_key,
        effect_type=item.effect_type,
        effect_value=item.effect_value,
        purchased_at=user_item.purchased_at,
    )


async def get_user_items(
    db: AsyncSession,
    user_id: uuid.UUID,
) -> list[UserItemResponse]:
    stmt = (
        select(UserItem, Item)
        .join(Item, Item.id == UserItem.item_id)
        .where(UserItem.user_id == user_id)
        .order_by(UserItem.purchased_at.desc())
    )
    result = await db.execute(stmt)
    rows = result.all()

    return [
        UserItemResponse(
            id=row.UserItem.id,
            item_id=row.Item.id,
            name=row.Item.name,
            category=row.Item.category,
            price=row.Item.price,
            rarity=row.Item.rarity,
            asset_key=row.Item.asset_key,
            effect_type=row.Item.effect_type,
            effect_value=row.Item.effect_value,
            purchased_at=row.UserItem.purchased_at,
        )
        for row in rows
    ]
