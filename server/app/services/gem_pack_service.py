import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.exceptions import AppException
from app.schemas.gem_pack import PurchaseResponse
from app.services import gem_pack_catalog, gem_service


async def purchase(
    db: AsyncSession, user_id: uuid.UUID, pack_id: str
) -> PurchaseResponse:
    pack = gem_pack_catalog.get_pack(pack_id)
    if pack is None:
        raise AppException(
            status_code=404,
            code="PACK_NOT_FOUND",
            message="해당 보석 팩을 찾을 수 없습니다.",
        )

    awarded = pack.gems + pack.bonus_gems
    await gem_service.award_gems(
        db=db,
        user_id=user_id,
        amount=awarded,
        reason="purchase_mock",
        reference_id=None,
    )
    balance = await gem_service.get_balance(db, user_id)
    return PurchaseResponse(
        awarded_gems=awarded,
        balance=balance,
        pack_id=pack_id,
    )
