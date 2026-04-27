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
