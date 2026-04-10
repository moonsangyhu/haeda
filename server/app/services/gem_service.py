import uuid

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.gem_transaction import GemTransaction


async def award_gems(
    db: AsyncSession,
    user_id: uuid.UUID,
    amount: int,
    reason: str,
    reference_id: uuid.UUID | None = None,
) -> None:
    transaction = GemTransaction(
        id=uuid.uuid4(),
        user_id=user_id,
        amount=amount,
        reason=reason,
        reference_id=reference_id,
    )
    db.add(transaction)
    await db.flush()


async def get_balance(db: AsyncSession, user_id: uuid.UUID) -> int:
    stmt = select(func.coalesce(func.sum(GemTransaction.amount), 0)).where(
        GemTransaction.user_id == user_id
    )
    result = await db.execute(stmt)
    return result.scalar_one()
