"""Unit tests: effective_today boundary cases"""
from datetime import date, datetime
from zoneinfo import ZoneInfo

import pytest

from app.utils.time import KST, effective_today


class TestEffectiveToday:
    def test_cutoff2_before_boundary(self):
        """cutoff=2, now=Mar 9 01:59 KST → Mar 8 (01:59 - 2h = Mar 8 23:59)"""
        now = datetime(2026, 3, 9, 1, 59, tzinfo=KST)
        result = effective_today(2, now=now)
        assert result == date(2026, 3, 8)

    def test_cutoff2_at_boundary(self):
        """cutoff=2, now=Mar 9 02:00 KST → Mar 9 (02:00 - 2h = Mar 9 00:00)"""
        now = datetime(2026, 3, 9, 2, 0, tzinfo=KST)
        result = effective_today(2, now=now)
        assert result == date(2026, 3, 9)

    def test_cutoff0_midnight(self):
        """cutoff=0, now=Mar 9 00:00 KST → Mar 9 (no offset)"""
        now = datetime(2026, 3, 9, 0, 0, tzinfo=KST)
        result = effective_today(0, now=now)
        assert result == date(2026, 3, 9)
