import calendar as cal_lib
import uuid
from datetime import date

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.challenge_member import ChallengeMember
from app.models.verification import Verification
from app.schemas.streak_calendar import DayStatus, StreakCalendarResponse, StreakDay
from app.services import user_stats_service


def _today() -> date:
    return date.today()


async def get_calendar(
    db: AsyncSession,
    user_id: uuid.UUID,
    year: int,
    month: int,
) -> StreakCalendarResponse:
    today = _today()

    join_stmt = select(func.min(ChallengeMember.joined_at)).where(
        ChallengeMember.user_id == user_id
    )
    join_result = await db.execute(join_stmt)
    earliest_joined = join_result.scalar_one_or_none()
    first_join_date = earliest_joined.date() if earliest_joined is not None else None

    streak, _verified_today = await user_stats_service.calculate_global_streak(
        db, user_id
    )

    last_day = cal_lib.monthrange(year, month)[1]
    month_start = date(year, month, 1)
    month_end = date(year, month, last_day)

    verified_dates: set[date] = set()
    if first_join_date is not None:
        v_stmt = (
            select(Verification.date)
            .where(
                Verification.user_id == user_id,
                Verification.date >= month_start,
                Verification.date <= month_end,
            )
            .distinct()
        )
        v_result = await db.execute(v_stmt)
        verified_dates = {row[0] for row in v_result.all()}

    days: list[StreakDay] = []
    for day_num in range(1, last_day + 1):
        d = date(year, month, day_num)
        days.append(
            StreakDay(
                date=d,
                status=_classify(d, today, first_join_date, verified_dates),
            )
        )

    return StreakCalendarResponse(
        streak=streak,
        first_join_date=first_join_date,
        year=year,
        month=month,
        days=days,
    )


def _classify(
    d: date,
    today: date,
    first_join_date: date | None,
    verified_dates: set[date],
) -> DayStatus:
    if d > today:
        return DayStatus.FUTURE
    if first_join_date is None or d < first_join_date:
        return DayStatus.BEFORE_JOIN
    if d in verified_dates:
        return DayStatus.SUCCESS
    if d == today:
        return DayStatus.TODAY_PENDING
    return DayStatus.FAILURE
