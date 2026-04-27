import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.schemas.comment import CommentCreateRequest
from app.services import comment_service, verification_service

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


@router.get("/{verification_id}/comments")
async def get_comments(
    verification_id: uuid.UUID,
    cursor: str | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await comment_service.get_comments(
        db=db,
        verification_id=verification_id,
        user_id=user_id,
        cursor=cursor,
        limit=limit,
    )
    return {"data": result.model_dump()}


@router.post("/{verification_id}/comments", status_code=201)
async def create_comment(
    verification_id: uuid.UUID,
    body: CommentCreateRequest,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await comment_service.create_comment(
        db=db,
        verification_id=verification_id,
        user_id=user_id,
        content=body.content,
    )
    return {"data": result.model_dump()}
