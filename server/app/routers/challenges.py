import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.services import calendar_service, challenge_service

router = APIRouter(prefix="/challenges", tags=["challenges"])


@router.get("/{challenge_id}")
async def get_challenge(
    challenge_id: uuid.UUID,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    detail = await challenge_service.get_challenge_detail(
        db=db,
        challenge_id=challenge_id,
        user_id=user_id,
    )
    return {"data": detail.model_dump()}


@router.get("/{challenge_id}/calendar")
async def get_calendar(
    challenge_id: uuid.UUID,
    year: int = Query(..., description="연도"),
    month: int = Query(..., ge=1, le=12, description="월 (1~12)"),
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    cal = await calendar_service.get_calendar(
        db=db,
        challenge_id=challenge_id,
        user_id=user_id,
        year=year,
        month=month,
    )
    return {"data": cal.model_dump()}
