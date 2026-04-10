import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.services import character_service

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/{user_id}/character")
async def get_user_character(
    user_id: uuid.UUID,
    _: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    character = await character_service.get_character(db, user_id)
    return {"data": character.model_dump()}
