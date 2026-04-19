import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.exceptions import AppException
from app.models.challenge import Challenge
from app.models.challenge_member import ChallengeMember
from app.models.item import Item
from app.models.room_equip import RoomEquipCr, RoomEquipCrSignature, RoomEquipMr
from app.models.user import User
from app.models.user_item import UserItem
from app.schemas.item import EquippedItemBrief
from app.schemas.room_equip import (
    RoomEquipCrResponse,
    RoomEquipCrUpdateRequest,
    RoomEquipMrResponse,
    RoomEquipMrUpdateRequest,
    SignatureBrief,
)

# slot field → expected item category
MR_SLOT_TO_CATEGORY: dict[str, str] = {
    "wall_item_id": "MR_WALL",
    "ceiling_item_id": "MR_CEILING",
    "window_item_id": "MR_WINDOW",
    "shelf_item_id": "MR_SHELF",
    "plant_item_id": "MR_PLANT",
    "desk_item_id": "MR_DESK",
    "rug_item_id": "MR_RUG",
    "floor_item_id": "MR_FLOOR",
}

CR_SLOT_TO_CATEGORY: dict[str, str] = {
    "wall_item_id": "CR_WALL",
    "window_item_id": "CR_WINDOW",
    "calendar_item_id": "CR_CALENDAR",
    "board_item_id": "CR_BOARD",
    "sofa_item_id": "CR_SOFA",
    "floor_item_id": "CR_FLOOR",
}

# readable slot name → field name (for DELETE path param)
MR_SLOT_NAMES: dict[str, str] = {
    "wall": "wall_item_id",
    "ceiling": "ceiling_item_id",
    "window": "window_item_id",
    "shelf": "shelf_item_id",
    "plant": "plant_item_id",
    "desk": "desk_item_id",
    "rug": "rug_item_id",
    "floor": "floor_item_id",
}

CR_SLOT_NAMES: dict[str, str] = {
    "wall": "wall_item_id",
    "window": "window_item_id",
    "calendar": "calendar_item_id",
    "board": "board_item_id",
    "sofa": "sofa_item_id",
    "floor": "floor_item_id",
}


async def _fetch_item_brief(
    db: AsyncSession, item_id: uuid.UUID | None
) -> EquippedItemBrief | None:
    if item_id is None:
        return None
    result = await db.execute(select(Item).where(Item.id == item_id))
    item = result.scalar_one_or_none()
    if item is None:
        return None
    return EquippedItemBrief(
        id=item.id,
        name=item.name,
        category=item.category,
        rarity=item.rarity,
        asset_key=item.asset_key,
        is_limited=item.is_limited,
    )


async def _validate_slot_item(
    db: AsyncSession,
    user_id: uuid.UUID,
    slot_field: str,
    item_id: uuid.UUID,
    slot_to_category: dict[str, str],
) -> None:
    """Validate item ownership and category match for a given slot."""
    expected_category = slot_to_category[slot_field]

    item_result = await db.execute(select(Item).where(Item.id == item_id))
    item = item_result.scalar_one_or_none()
    if item is None:
        raise AppException(
            status_code=404,
            code="ITEM_NOT_FOUND",
            message=f"아이템을 찾을 수 없습니다: {item_id}",
        )

    if item.category.upper() != expected_category:
        raise AppException(
            status_code=422,
            code="ITEM_CATEGORY_MISMATCH",
            message=f"{slot_field} 슬롯에는 {expected_category} 카테고리 아이템만 장착할 수 있습니다.",
        )

    owned_result = await db.execute(
        select(UserItem).where(
            UserItem.user_id == user_id,
            UserItem.item_id == item_id,
        )
    )
    if owned_result.scalar_one_or_none() is None:
        raise AppException(
            status_code=403,
            code="ITEM_NOT_OWNED",
            message="보유하지 않은 아이템입니다.",
        )


# ---------------------------------------------------------------------------
# Mini-room (personal)
# ---------------------------------------------------------------------------

async def get_miniroom(db: AsyncSession, user_id: uuid.UUID) -> RoomEquipMrResponse:
    result = await db.execute(
        select(RoomEquipMr).where(RoomEquipMr.user_id == user_id)
    )
    equip = result.scalar_one_or_none()

    if equip is None:
        return RoomEquipMrResponse()

    return RoomEquipMrResponse(
        wall=await _fetch_item_brief(db, equip.wall_item_id),
        ceiling=await _fetch_item_brief(db, equip.ceiling_item_id),
        window=await _fetch_item_brief(db, equip.window_item_id),
        shelf=await _fetch_item_brief(db, equip.shelf_item_id),
        plant=await _fetch_item_brief(db, equip.plant_item_id),
        desk=await _fetch_item_brief(db, equip.desk_item_id),
        rug=await _fetch_item_brief(db, equip.rug_item_id),
        floor=await _fetch_item_brief(db, equip.floor_item_id),
        updated_at=equip.updated_at,
    )


async def update_miniroom(
    db: AsyncSession,
    user_id: uuid.UUID,
    request: RoomEquipMrUpdateRequest,
) -> RoomEquipMrResponse:
    # Validate all specified slots
    for slot_field, item_id in request.model_dump(exclude_none=True).items():
        await _validate_slot_item(db, user_id, slot_field, item_id, MR_SLOT_TO_CATEGORY)

    result = await db.execute(
        select(RoomEquipMr).where(RoomEquipMr.user_id == user_id)
    )
    equip = result.scalar_one_or_none()

    if equip is None:
        equip = RoomEquipMr(user_id=user_id)
        db.add(equip)

    for slot_field in request.model_fields_set:
        setattr(equip, slot_field, getattr(request, slot_field))

    await db.commit()
    await db.refresh(equip)
    return await get_miniroom(db, user_id)


async def clear_miniroom_slot(
    db: AsyncSession,
    user_id: uuid.UUID,
    slot: str,
) -> RoomEquipMrResponse:
    slot_field = MR_SLOT_NAMES.get(slot)
    if slot_field is None:
        raise AppException(
            status_code=422,
            code="INVALID_SLOT",
            message=f"유효하지 않은 슬롯입니다: {slot}",
        )

    result = await db.execute(
        select(RoomEquipMr).where(RoomEquipMr.user_id == user_id)
    )
    equip = result.scalar_one_or_none()

    if equip is not None:
        setattr(equip, slot_field, None)
        await db.commit()
        await db.refresh(equip)

    return await get_miniroom(db, user_id)


# ---------------------------------------------------------------------------
# Challenge room (shared)
# ---------------------------------------------------------------------------

async def _build_cr_response(
    db: AsyncSession,
    equip: RoomEquipCr | None,
    challenge_id: uuid.UUID,
) -> RoomEquipCrResponse:
    # Fetch signatures with user nicknames
    sigs_result = await db.execute(
        select(RoomEquipCrSignature, User)
        .join(User, User.id == RoomEquipCrSignature.user_id)
        .where(RoomEquipCrSignature.challenge_id == challenge_id)
    )
    sig_rows = sigs_result.all()

    signatures = []
    for sig, user in sig_rows:
        sig_item = await _fetch_item_brief(db, sig.signature_item_id)
        signatures.append(SignatureBrief(
            user_id=user.id,
            nickname=user.nickname,
            signature_item=sig_item,
        ))

    if equip is None:
        return RoomEquipCrResponse(signatures=signatures)

    return RoomEquipCrResponse(
        wall=await _fetch_item_brief(db, equip.wall_item_id),
        window=await _fetch_item_brief(db, equip.window_item_id),
        calendar=await _fetch_item_brief(db, equip.calendar_item_id),
        board=await _fetch_item_brief(db, equip.board_item_id),
        sofa=await _fetch_item_brief(db, equip.sofa_item_id),
        floor=await _fetch_item_brief(db, equip.floor_item_id),
        signatures=signatures,
        updated_by_user_id=equip.updated_by_user_id,
        updated_at=equip.updated_at,
    )


async def get_challenge_room(
    db: AsyncSession,
    challenge_id: uuid.UUID,
) -> RoomEquipCrResponse:
    result = await db.execute(
        select(RoomEquipCr).where(RoomEquipCr.challenge_id == challenge_id)
    )
    equip = result.scalar_one_or_none()
    return await _build_cr_response(db, equip, challenge_id)


async def _assert_challenge_creator(
    db: AsyncSession,
    challenge_id: uuid.UUID,
    user_id: uuid.UUID,
) -> Challenge:
    result = await db.execute(
        select(Challenge).where(Challenge.id == challenge_id)
    )
    challenge = result.scalar_one_or_none()
    if challenge is None:
        raise AppException(
            status_code=404,
            code="CHALLENGE_NOT_FOUND",
            message="챌린지를 찾을 수 없습니다.",
        )
    if challenge.creator_id != user_id:
        raise AppException(
            status_code=403,
            code="CR_NOT_CREATOR",
            message="챌린지 방장만 방을 꾸밀 수 있습니다.",
        )
    return challenge


async def _assert_challenge_member(
    db: AsyncSession,
    challenge_id: uuid.UUID,
    user_id: uuid.UUID,
) -> None:
    result = await db.execute(
        select(ChallengeMember).where(
            ChallengeMember.challenge_id == challenge_id,
            ChallengeMember.user_id == user_id,
        )
    )
    if result.scalar_one_or_none() is None:
        raise AppException(
            status_code=403,
            code="CR_NOT_MEMBER",
            message="챌린지 멤버만 시그니처를 설정할 수 있습니다.",
        )


async def update_challenge_room(
    db: AsyncSession,
    challenge_id: uuid.UUID,
    user_id: uuid.UUID,
    request: RoomEquipCrUpdateRequest,
) -> RoomEquipCrResponse:
    await _assert_challenge_creator(db, challenge_id, user_id)

    # Validate all specified slots
    for slot_field, item_id in request.model_dump(exclude_none=True).items():
        await _validate_slot_item(db, user_id, slot_field, item_id, CR_SLOT_TO_CATEGORY)

    result = await db.execute(
        select(RoomEquipCr).where(RoomEquipCr.challenge_id == challenge_id)
    )
    equip = result.scalar_one_or_none()

    if equip is None:
        equip = RoomEquipCr(challenge_id=challenge_id)
        db.add(equip)

    for slot_field in request.model_fields_set:
        setattr(equip, slot_field, getattr(request, slot_field))

    equip.updated_by_user_id = user_id
    await db.commit()
    await db.refresh(equip)
    return await _build_cr_response(db, equip, challenge_id)


async def clear_challenge_room_slot(
    db: AsyncSession,
    challenge_id: uuid.UUID,
    user_id: uuid.UUID,
    slot: str,
) -> RoomEquipCrResponse:
    slot_field = CR_SLOT_NAMES.get(slot)
    if slot_field is None:
        raise AppException(
            status_code=422,
            code="INVALID_SLOT",
            message=f"유효하지 않은 슬롯입니다: {slot}",
        )

    await _assert_challenge_creator(db, challenge_id, user_id)

    result = await db.execute(
        select(RoomEquipCr).where(RoomEquipCr.challenge_id == challenge_id)
    )
    equip = result.scalar_one_or_none()

    if equip is not None:
        setattr(equip, slot_field, None)
        equip.updated_by_user_id = user_id
        await db.commit()
        await db.refresh(equip)

    return await _build_cr_response(db, equip, challenge_id)


# ---------------------------------------------------------------------------
# Signature
# ---------------------------------------------------------------------------

async def set_signature(
    db: AsyncSession,
    challenge_id: uuid.UUID,
    user_id: uuid.UUID,
    item_id: uuid.UUID,
) -> RoomEquipCrResponse:
    # Must be a member
    await _assert_challenge_member(db, challenge_id, user_id)

    # Validate item exists and is SIGNATURE category
    item_result = await db.execute(select(Item).where(Item.id == item_id))
    item = item_result.scalar_one_or_none()
    if item is None:
        raise AppException(
            status_code=404,
            code="ITEM_NOT_FOUND",
            message=f"아이템을 찾을 수 없습니다: {item_id}",
        )
    if item.category.upper() != "SIGNATURE":
        raise AppException(
            status_code=422,
            code="ITEM_CATEGORY_MISMATCH",
            message="시그니처 슬롯에는 SIGNATURE 카테고리 아이템만 장착할 수 있습니다.",
        )

    # Validate ownership
    owned_result = await db.execute(
        select(UserItem).where(
            UserItem.user_id == user_id,
            UserItem.item_id == item_id,
        )
    )
    if owned_result.scalar_one_or_none() is None:
        raise AppException(
            status_code=403,
            code="ITEM_NOT_OWNED",
            message="보유하지 않은 아이템입니다.",
        )

    # Upsert
    sig_result = await db.execute(
        select(RoomEquipCrSignature).where(
            RoomEquipCrSignature.challenge_id == challenge_id,
            RoomEquipCrSignature.user_id == user_id,
        )
    )
    sig = sig_result.scalar_one_or_none()

    if sig is None:
        sig = RoomEquipCrSignature(
            id=uuid.uuid4(),
            challenge_id=challenge_id,
            user_id=user_id,
            signature_item_id=item_id,
        )
        db.add(sig)
    else:
        sig.signature_item_id = item_id

    await db.commit()

    cr_result = await db.execute(
        select(RoomEquipCr).where(RoomEquipCr.challenge_id == challenge_id)
    )
    equip = cr_result.scalar_one_or_none()
    return await _build_cr_response(db, equip, challenge_id)


async def clear_signature(
    db: AsyncSession,
    challenge_id: uuid.UUID,
    user_id: uuid.UUID,
) -> RoomEquipCrResponse:
    # Must be a member (idempotent, but still enforce membership)
    await _assert_challenge_member(db, challenge_id, user_id)

    sig_result = await db.execute(
        select(RoomEquipCrSignature).where(
            RoomEquipCrSignature.challenge_id == challenge_id,
            RoomEquipCrSignature.user_id == user_id,
        )
    )
    sig = sig_result.scalar_one_or_none()

    if sig is not None:
        await db.delete(sig)
        await db.commit()

    cr_result = await db.execute(
        select(RoomEquipCr).where(RoomEquipCr.challenge_id == challenge_id)
    )
    equip = cr_result.scalar_one_or_none()
    return await _build_cr_response(db, equip, challenge_id)
