import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.services import verification_service

router = APIRouter(prefix="/verifications", tags=["verifications"])


@router.get("/{verification_id}")
async def get_verification_detail(
    verification_id: uuid.UUID,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await verification_service.get_verification_detail(
        db=db,
        verification_id=verification_id,
        user_id=user_id,
    )
    return {"data": result.model_dump()}
