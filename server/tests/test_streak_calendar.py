"""GET /me/streak/calendar — 전역 streak 캘린더 테스트"""
import uuid
from datetime import date, datetime
from unittest.mock import patch

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.challenge import Challenge
from app.models.challenge_member import ChallengeMember
from app.models.user import User
from app.models.verification import Verification
from app.schemas.streak_calendar import DayStatus
from app.services import streak_calendar_service


@pytest.mark.asyncio
async def test_no_membership_user_all_before_join(
    db_session: AsyncSession, user: User
):
    """챌린지 미참여 유저: first_join_date=None, 모든 날짜 before_join."""
    today = date(2026, 4, 27)
    with patch("app.services.streak_calendar_service._today", return_value=today):
        result = await streak_calendar_service.get_calendar(
            db=db_session, user_id=user.id, year=2026, month=4
        )

    assert result.streak == 0
    assert result.first_join_date is None
    assert result.year == 2026
    assert result.month == 4
    assert len(result.days) == 30
    past = [d for d in result.days if d.date <= today]
    future = [d for d in result.days if d.date > today]
    assert all(d.status == DayStatus.BEFORE_JOIN for d in past)
    assert all(d.status == DayStatus.FUTURE for d in future)


@pytest.mark.asyncio
async def test_yesterday_verified_is_success(
    db_session: AsyncSession,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    """어제 인증 → success. 오늘 인증 X → today_pending."""
    today = date(2026, 4, 27)
    yesterday = date(2026, 4, 26)

    membership.joined_at = datetime(2026, 4, 1, 0, 0, 0)
    db_session.add(
        Verification(
            id=uuid.uuid4(),
            challenge_id=challenge.id,
            user_id=user.id,
            date=yesterday,
            photo_urls=None,
            diary_text="어제 운동",
        )
    )
    await db_session.commit()

    with patch("app.services.streak_calendar_service._today", return_value=today):
        result = await streak_calendar_service.get_calendar(
            db=db_session, user_id=user.id, year=2026, month=4
        )

    by_date = {d.date: d.status for d in result.days}
    assert by_date[yesterday] == DayStatus.SUCCESS
    assert by_date[today] == DayStatus.TODAY_PENDING
    assert by_date[date(2026, 4, 2)] == DayStatus.FAILURE
    assert by_date[date(2026, 4, 25)] == DayStatus.FAILURE
    assert by_date[date(2026, 4, 1)] == DayStatus.FAILURE
    assert by_date[date(2026, 4, 30)] == DayStatus.FUTURE


@pytest.mark.asyncio
async def test_today_verified_is_success(
    db_session: AsyncSession,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    """오늘 인증 완료 → today 도 success."""
    today = date(2026, 4, 27)
    membership.joined_at = datetime(2026, 4, 1, 0, 0, 0)
    db_session.add(
        Verification(
            id=uuid.uuid4(),
            challenge_id=challenge.id,
            user_id=user.id,
            date=today,
            photo_urls=None,
            diary_text="오늘 운동",
        )
    )
    await db_session.commit()

    with patch("app.services.streak_calendar_service._today", return_value=today):
        result = await streak_calendar_service.get_calendar(
            db=db_session, user_id=user.id, year=2026, month=4
        )

    by_date = {d.date: d.status for d in result.days}
    assert by_date[today] == DayStatus.SUCCESS


@pytest.mark.asyncio
async def test_same_day_two_challenges_one_success(
    db_session: AsyncSession,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    """같은 날 두 챌린지 인증 → 한 칸만 success."""
    today = date(2026, 4, 27)
    yesterday = date(2026, 4, 26)
    membership.joined_at = datetime(2026, 4, 1, 0, 0, 0)

    challenge2 = Challenge(
        id=uuid.uuid4(),
        creator_id=user.id,
        title="독서",
        description="매일 독서",
        category="공부",
        start_date=date(2026, 4, 1),
        end_date=date(2026, 4, 30),
        verification_frequency={"type": "daily"},
        photo_required=False,
        invite_code="WXYZ9999",
        status="active",
    )
    db_session.add(challenge2)
    await db_session.flush()
    db_session.add(
        ChallengeMember(
            id=uuid.uuid4(),
            challenge_id=challenge2.id,
            user_id=user.id,
            joined_at=datetime(2026, 4, 1, 0, 0, 0),
        )
    )
    db_session.add_all(
        [
            Verification(
                id=uuid.uuid4(),
                challenge_id=challenge.id,
                user_id=user.id,
                date=yesterday,
                photo_urls=None,
                diary_text="운동",
            ),
            Verification(
                id=uuid.uuid4(),
                challenge_id=challenge2.id,
                user_id=user.id,
                date=yesterday,
                photo_urls=None,
                diary_text="독서",
            ),
        ]
    )
    await db_session.commit()

    with patch("app.services.streak_calendar_service._today", return_value=today):
        result = await streak_calendar_service.get_calendar(
            db=db_session, user_id=user.id, year=2026, month=4
        )

    by_date = {d.date: d.status for d in result.days}
    assert by_date[yesterday] == DayStatus.SUCCESS
    success_count = sum(1 for s in by_date.values() if s == DayStatus.SUCCESS)
    assert success_count == 1


@pytest.mark.asyncio
async def test_join_date_future_to_queried_month(
    db_session: AsyncSession,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
):
    """가입일이 조회 월보다 미래 → 모든 날짜 before_join 또는 future."""
    today = date(2026, 4, 27)
    membership.joined_at = datetime(2026, 5, 10, 0, 0, 0)
    await db_session.commit()

    with patch("app.services.streak_calendar_service._today", return_value=today):
        result = await streak_calendar_service.get_calendar(
            db=db_session, user_id=user.id, year=2026, month=4
        )

    assert all(
        d.status in (DayStatus.BEFORE_JOIN, DayStatus.FUTURE) for d in result.days
    )
