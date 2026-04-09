import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.services import notification_service

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("")
async def get_notifications(
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await notification_service.get_notifications(
        db=db,
        user_id=user_id,
        limit=limit,
        offset=offset,
    )
    return {"data": result.model_dump()}


@router.put("/{notification_id}/read")
async def mark_as_read(
    notification_id: uuid.UUID,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    await notification_service.mark_as_read(
        db=db,
        notification_id=notification_id,
        user_id=user_id,
    )
    return {"data": {"success": True}}


@router.get("/unread-count")
async def get_unread_count(
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    count = await notification_service.get_unread_count(db=db, user_id=user_id)
    return {"data": {"count": count}}
