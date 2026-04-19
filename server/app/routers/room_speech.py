import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.schemas.room_speech import RoomSpeechCreateRequest
from app.services import room_speech_service

router = APIRouter(
    prefix="/challenges/{challenge_id}/room-speech",
    tags=["room-speech"],
)


@router.get("")
async def list_room_speech(
    challenge_id: uuid.UUID,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    items = await room_speech_service.list_room_speech(db, challenge_id, user_id)
    return {"data": [item.model_dump() for item in items]}


@router.post("")
async def submit_room_speech(
    challenge_id: uuid.UUID,
    body: RoomSpeechCreateRequest,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await room_speech_service.submit_room_speech(db, challenge_id, user_id, body.content)
    return {"data": result.model_dump()}


@router.delete("")
async def delete_room_speech(
    challenge_id: uuid.UUID,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await room_speech_service.delete_room_speech(db, challenge_id, user_id)
    return {"data": result.model_dump()}
