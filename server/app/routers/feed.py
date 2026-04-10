import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.services import feed_service

router = APIRouter(prefix="/feed", tags=["feed"])


@router.get("")
async def get_feed(
    cursor: str | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=50),
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await feed_service.get_friend_feed(
        db=db,
        user_id=user_id,
        cursor=cursor,
        limit=limit,
    )
    return {"data": result.model_dump()}


@router.post("/{feed_item_id}/clap")
async def toggle_clap(
    feed_item_id: uuid.UUID,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await feed_service.toggle_clap(
        db=db,
        feed_item_id=feed_item_id,
        user_id=user_id,
    )
    return {"data": result.model_dump()}


@router.get("/{feed_item_id}/claps")
async def get_clap_count(
    feed_item_id: uuid.UUID,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import func, select
    from app.models.clap import Clap

    count_result = await db.execute(
        select(func.count(Clap.id)).where(Clap.feed_item_id == feed_item_id)
    )
    clap_count: int = count_result.scalar_one()
    return {"data": {"clap_count": clap_count}}
