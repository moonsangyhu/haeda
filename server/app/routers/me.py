import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.services import challenge_service

router = APIRouter(prefix="/me", tags=["me"])


@router.get("/challenges")
async def get_my_challenges(
    status: str | None = Query(default=None, description="active / completed (기본: 전체)"),
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    challenges = await challenge_service.get_my_challenges(
        db=db,
        user_id=user_id,
        status_filter=status,
    )
    return {"data": {"challenges": [c.model_dump() for c in challenges]}}
