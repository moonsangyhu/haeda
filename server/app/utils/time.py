from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

KST = ZoneInfo("Asia/Seoul")


def effective_today(cutoff_hour: int, now: datetime | None = None) -> date:
    if now is None:
        now = datetime.now(tz=KST)
    return (now - timedelta(hours=cutoff_hour)).date()
