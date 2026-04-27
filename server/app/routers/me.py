import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.exceptions import AppException
from app.models.gem_transaction import GemTransaction
from app.models.user import User
from app.schemas.coin import CoinBalanceResponse
from app.schemas.item import AppearanceUpdateRequest, CharacterUpdateRequest
from app.schemas.user import UserBrief
from app.services import (
    challenge_service,
    character_service,
    gem_service,
    shop_service,
    streak_calendar_service,
    user_stats_service,
)

router = APIRouter(prefix="/me", tags=["me"])


@router.get("")
async def get_me(
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise AppException(status_code=404, code="USER_NOT_FOUND", message="사용자를 찾을 수 없습니다.")
    brief = UserBrief(
        id=user.id,
        nickname=user.nickname,
        discriminator=user.discriminator,
        profile_image_url=user.profile_image_url,
        background_color=user.background_color,
    )
    return {"data": brief.model_dump()}


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


@router.get("/stats")
async def get_my_stats(
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    stats = await user_stats_service.get_user_stats(db=db, user_id=user_id)
    return {"data": stats.model_dump()}


@router.get("/coins")
async def get_coin_balance(
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    balance = await gem_service.get_balance(db, user_id)
    return {"data": CoinBalanceResponse(balance=balance).model_dump()}


@router.get("/coins/transactions")
async def get_coin_transactions(
    cursor: str | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=50),
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(GemTransaction)
        .where(GemTransaction.user_id == user_id)
        .order_by(GemTransaction.created_at.desc())
    )
    if cursor:
        try:
            cursor_id = uuid.UUID(cursor)
            # find the created_at of the cursor transaction for keyset pagination
            cursor_stmt = select(GemTransaction.created_at).where(GemTransaction.id == cursor_id)
            cursor_result = await db.execute(cursor_stmt)
            cursor_ts = cursor_result.scalar_one_or_none()
            if cursor_ts is not None:
                stmt = stmt.where(GemTransaction.created_at < cursor_ts)
        except (ValueError, AttributeError):
            pass

    stmt = stmt.limit(limit + 1)
    result = await db.execute(stmt)
    rows = result.scalars().all()

    has_more = len(rows) > limit
    items = rows[:limit]
    next_cursor = str(items[-1].id) if has_more else None

    return {
        "data": {
            "items": [
                {
                    "id": str(tx.id),
                    "amount": tx.amount,
                    "type": tx.reason,
                    "reference_id": str(tx.reference_id) if tx.reference_id else None,
                    "created_at": tx.created_at.isoformat(),
                }
                for tx in items
            ],
            "next_cursor": next_cursor,
        }
    }


@router.get("/items")
async def get_my_items(
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    items = await shop_service.get_user_items(db, user_id)
    return {
        "data": [
            {
                "id": str(i.id),
                "item": {
                    "id": str(i.item_id),
                    "name": i.name,
                    "category": i.category,
                    "price": i.price,
                    "rarity": i.rarity,
                    "asset_key": i.asset_key,
                    "effect_type": i.effect_type,
                    "effect_value": i.effect_value,
                },
                "purchased_at": i.purchased_at.isoformat(),
            }
            for i in items
        ]
    }


@router.get("/character")
async def get_my_character(
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    character = await character_service.get_character(db, user_id)
    return {"data": character.model_dump()}


@router.put("/character")
async def update_my_character(
    body: CharacterUpdateRequest,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    character = await character_service.update_character(db, user_id, body)
    return {"data": character.model_dump()}


@router.put("/character/appearance")
async def update_my_appearance(
    body: AppearanceUpdateRequest,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await character_service.update_appearance(db, user_id, body)
    return {"data": result.model_dump()}


@router.get("/streak/calendar")
async def get_streak_calendar(
    year: int = Query(..., description="조회 연도"),
    month: int = Query(..., description="조회 월 (1~12)"),
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    if year < 2024 or year > 2100 or month < 1 or month > 12:
        raise AppException(
            status_code=400,
            code="INVALID_MONTH",
            message="잘못된 연도/월입니다.",
        )
    cal = await streak_calendar_service.get_calendar(
        db=db, user_id=user_id, year=year, month=month
    )
    return {"data": cal.model_dump(mode="json")}
