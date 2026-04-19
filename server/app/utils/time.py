from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

KST = ZoneInfo("Asia/Seoul")

_GUARD_SECONDS = 30


def effective_today(cutoff_hour: int, now: datetime | None = None) -> date:
    if now is None:
        now = datetime.now(tz=KST)
    return (now - timedelta(hours=cutoff_hour)).date()


def next_cutoff_at(cutoff_hour: int, now: datetime | None = None) -> datetime:
    """Return the next KST moment when the effective day rolls over.

    If the upcoming cutoff is within 30 seconds, push to the cutoff after that
    to avoid immediate-expiry on boundary posts.
    """
    if now is None:
        now = datetime.now(tz=KST)
    now_kst = now.astimezone(KST)
    candidate = now_kst.replace(hour=cutoff_hour, minute=0, second=0, microsecond=0)
    if candidate <= now_kst:
        candidate += timedelta(days=1)
    if (candidate - now_kst).total_seconds() < _GUARD_SECONDS:
        candidate += timedelta(days=1)
    return candidate
