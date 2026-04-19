import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.exceptions import AppException
from app.schemas.room_equip import (
    RoomEquipCrUpdateRequest,
    RoomEquipMrUpdateRequest,
    SignatureUpdateRequest,
)
from app.services import room_equip_service

router = APIRouter(tags=["room-equip"])

VALID_MR_SLOTS = set(room_equip_service.MR_SLOT_NAMES.keys())
VALID_CR_SLOTS = set(room_equip_service.CR_SLOT_NAMES.keys())


# ---------------------------------------------------------------------------
# Mini-room (personal)
# ---------------------------------------------------------------------------

@router.get("/me/room/miniroom")
async def get_miniroom(
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await room_equip_service.get_miniroom(db, user_id)
    return {"data": result.model_dump()}


@router.put("/me/room/miniroom")
async def update_miniroom(
    body: RoomEquipMrUpdateRequest,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await room_equip_service.update_miniroom(db, user_id, body)
    return {"data": result.model_dump()}


@router.delete("/me/room/miniroom/{slot}")
async def clear_miniroom_slot(
    slot: str,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    if slot not in VALID_MR_SLOTS:
        raise AppException(
            status_code=422,
            code="INVALID_SLOT",
            message=f"유효하지 않은 슬롯입니다. 가능한 값: {', '.join(sorted(VALID_MR_SLOTS))}",
        )
    result = await room_equip_service.clear_miniroom_slot(db, user_id, slot)
    return {"data": result.model_dump()}


# ---------------------------------------------------------------------------
# Challenge room (shared)
# ---------------------------------------------------------------------------

@router.get("/challenges/{challenge_id}/room")
async def get_challenge_room(
    challenge_id: uuid.UUID,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await room_equip_service.get_challenge_room(db, challenge_id)
    return {"data": result.model_dump()}


@router.put("/challenges/{challenge_id}/room")
async def update_challenge_room(
    challenge_id: uuid.UUID,
    body: RoomEquipCrUpdateRequest,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await room_equip_service.update_challenge_room(db, challenge_id, user_id, body)
    return {"data": result.model_dump()}


@router.delete("/challenges/{challenge_id}/room/{slot}")
async def clear_challenge_room_slot(
    challenge_id: uuid.UUID,
    slot: str,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    if slot not in VALID_CR_SLOTS:
        raise AppException(
            status_code=422,
            code="INVALID_SLOT",
            message=f"유효하지 않은 슬롯입니다. 가능한 값: {', '.join(sorted(VALID_CR_SLOTS))}",
        )
    result = await room_equip_service.clear_challenge_room_slot(db, challenge_id, user_id, slot)
    return {"data": result.model_dump()}


# ---------------------------------------------------------------------------
# Signature
# ---------------------------------------------------------------------------

@router.put("/challenges/{challenge_id}/room/signature")
async def set_signature(
    challenge_id: uuid.UUID,
    body: SignatureUpdateRequest,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await room_equip_service.set_signature(db, challenge_id, user_id, body.signature_item_id)
    return {"data": result.model_dump()}


@router.delete("/challenges/{challenge_id}/room/signature")
async def clear_signature(
    challenge_id: uuid.UUID,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await room_equip_service.clear_signature(db, challenge_id, user_id)
    return {"data": result.model_dump()}
