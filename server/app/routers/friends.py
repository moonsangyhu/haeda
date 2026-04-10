import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.schemas.friendship import (
    ContactMatchRequest,
    FriendRequestCreate,
)
from app.services import friend_service

router = APIRouter(prefix="/friends", tags=["friends"])


@router.post("/requests", status_code=201)
async def send_friend_request(
    body: FriendRequestCreate,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await friend_service.send_friend_request(
        db=db,
        requester_id=user_id,
        addressee_id=body.addressee_id,
    )
    return {"data": result.model_dump()}


@router.get("/requests/pending")
async def get_pending_requests(
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await friend_service.get_pending_requests(db=db, user_id=user_id)
    return {"data": result.model_dump()}


@router.put("/requests/{friendship_id}/accept")
async def accept_friend_request(
    friendship_id: uuid.UUID,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await friend_service.accept_friend_request(
        db=db,
        friendship_id=friendship_id,
        user_id=user_id,
    )
    return {"data": result.model_dump()}


@router.put("/requests/{friendship_id}/reject")
async def reject_friend_request(
    friendship_id: uuid.UUID,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await friend_service.reject_friend_request(
        db=db,
        friendship_id=friendship_id,
        user_id=user_id,
    )
    return {"data": result.model_dump()}


@router.get("")
async def get_friends(
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await friend_service.get_friends(db=db, user_id=user_id)
    return {"data": result.model_dump()}


@router.delete("/{friendship_id}", status_code=200)
async def remove_friend(
    friendship_id: uuid.UUID,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    await friend_service.remove_friend(
        db=db,
        friendship_id=friendship_id,
        user_id=user_id,
    )
    return {"data": {"success": True}}


@router.post("/contact-match")
async def match_contacts(
    body: ContactMatchRequest,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await friend_service.match_contacts(
        db=db,
        user_id=user_id,
        phone_numbers=body.phone_numbers,
    )
    return {"data": result.model_dump()}
