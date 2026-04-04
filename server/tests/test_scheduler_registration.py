"""Tests for scheduler registration in main.py (slice-06 보완)."""
import pytest

from app.main import lifespan, app, scheduler


@pytest.mark.asyncio
async def test_scheduler_running_and_job_registered():
    """lifespan startup 후 scheduler가 running이고 job이 등록됨."""
    async with lifespan(app):
        assert scheduler.running is True
        job = scheduler.get_job("close_expired_challenges")
        assert job is not None


@pytest.mark.asyncio
async def test_scheduler_job_trigger_is_daily_midnight():
    """등록된 job의 trigger가 매일 자정(hour=0, minute=0)인지 확인."""
    async with lifespan(app):
        job = scheduler.get_job("close_expired_challenges")
        assert job is not None

        trigger = job.trigger
        hour_field = trigger.fields[trigger.FIELD_NAMES.index("hour")]
        minute_field = trigger.fields[trigger.FIELD_NAMES.index("minute")]

        assert str(hour_field) == "0"
        assert str(minute_field) == "0"
