"""단위 테스트: 달성률 계산, 계절 판정"""
from datetime import date

from app.services.challenge_service import _compute_achievement_rate
from app.services.calendar_service import _determine_season


class TestAchievementRate:
    def test_daily_full(self):
        # 30일 챌린지, 30회 인증 = 100.0%
        result = _compute_achievement_rate(30, date(2026, 4, 1), date(2026, 4, 30), {"type": "daily"})
        assert result == 100.0

    def test_daily_partial(self):
        # 30일 챌린지, 10회 인증 = 33.3%
        result = _compute_achievement_rate(10, date(2026, 4, 1), date(2026, 4, 30), {"type": "daily"})
        assert result == 33.3

    def test_daily_zero(self):
        result = _compute_achievement_rate(0, date(2026, 4, 1), date(2026, 4, 30), {"type": "daily"})
        assert result == 0.0

    def test_weekly(self):
        # 30일 = ceil(30/7)=5주 × 3회/주 = 15 기대, 10회 인증 = 66.7%
        result = _compute_achievement_rate(
            10, date(2026, 4, 1), date(2026, 4, 30), {"type": "weekly", "times_per_week": 3}
        )
        assert result == 66.7

    def test_weekly_full(self):
        # 14일 = ceil(14/7)=2주 × 2회/주 = 4 기대, 4회 인증 = 100.0%
        result = _compute_achievement_rate(
            4, date(2026, 4, 1), date(2026, 4, 14), {"type": "weekly", "times_per_week": 2}
        )
        assert result == 100.0


class TestSeasonDetermination:
    def test_spring(self):
        for m in [3, 4, 5]:
            assert _determine_season(m) == "spring"

    def test_summer(self):
        for m in [6, 7, 8]:
            assert _determine_season(m) == "summer"

    def test_fall(self):
        for m in [9, 10, 11]:
            assert _determine_season(m) == "fall"

    def test_winter(self):
        for m in [12, 1, 2]:
            assert _determine_season(m) == "winter"
