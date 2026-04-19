import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.services import gem_service, shop_service

router = APIRouter(prefix="/shop", tags=["shop"])


@router.get("/items")
async def list_shop_items(
    category: str | None = Query(default=None),
    is_limited: bool | None = Query(default=None),
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    items = await shop_service.list_items(db, user_id, category, is_limited)
    return {"data": [i.model_dump() for i in items]}


@router.post("/items/{item_id}/purchase", status_code=201)
async def purchase_item(
    item_id: uuid.UUID,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    purchased = await shop_service.purchase_item(db, user_id, item_id)
    remaining_balance = await gem_service.get_balance(db, user_id)
    return {"data": {"item_id": str(purchased.item_id), "remaining_balance": remaining_balance}}
