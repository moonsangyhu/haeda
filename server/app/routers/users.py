import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.schemas.user_search import UserSearchByIdRequest
from app.services import character_service, user_search_service

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/{user_id}/character")
async def get_user_character(
    user_id: uuid.UUID,
    _: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    character = await character_service.get_character(db, user_id)
    return {"data": character.model_dump()}


@router.post("/search-by-id")
async def search_user_by_id(
    body: UserSearchByIdRequest,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await user_search_service.search_by_id(
        db,
        viewer_id=user_id,
        nickname=body.nickname,
        discriminator=body.discriminator,
    )
    return {"data": result.model_dump(mode="json")}
