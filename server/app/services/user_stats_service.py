import uuid
from datetime import date, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.challenge import Challenge
from app.models.challenge_member import ChallengeMember
from app.models.verification import Verification
from app.schemas.user import UserStatsResponse
from app.services import gem_service


async def calculate_global_streak(
    db: AsyncSession, user_id: uuid.UUID
) -> tuple[int, bool]:
    today = date.today()

    stmt = (
        select(Verification.date)
        .where(Verification.user_id == user_id)
        .distinct()
        .order_by(Verification.date.desc())
    )
    result = await db.execute(stmt)
    dates = [row[0] for row in result.all()]

    if not dates:
        return 0, False

    verified_today = dates[0] == today

    streak = 0
    expected = today
    for d in dates:
        if d == expected:
            streak += 1
            expected = expected - timedelta(days=1)
        else:
            break

    return streak, verified_today


async def get_user_stats(db: AsyncSession, user_id: uuid.UUID) -> UserStatsResponse:
    streak, verified_today = await calculate_global_streak(db, user_id)

    active_stmt = (
        select(func.count())
        .select_from(ChallengeMember)
        .join(Challenge, Challenge.id == ChallengeMember.challenge_id)
        .where(
            ChallengeMember.user_id == user_id,
            Challenge.status == "active",
        )
    )
    active_result = await db.execute(active_stmt)
    active_challenges = active_result.scalar_one()

    completed_stmt = (
        select(func.count())
        .select_from(ChallengeMember)
        .join(Challenge, Challenge.id == ChallengeMember.challenge_id)
        .where(
            ChallengeMember.user_id == user_id,
            Challenge.status == "completed",
        )
    )
    completed_result = await db.execute(completed_stmt)
    completed_challenges = completed_result.scalar_one()

    gem_balance = await gem_service.get_balance(db, user_id)

    return UserStatsResponse(
        streak=streak,
        verified_today=verified_today,
        active_challenges=active_challenges,
        completed_challenges=completed_challenges,
        gems=gem_balance,
    )
