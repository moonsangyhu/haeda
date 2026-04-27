from datetime import date
from enum import Enum

from pydantic import BaseModel


class DayStatus(str, Enum):
    SUCCESS = "success"
    FAILURE = "failure"
    TODAY_PENDING = "today_pending"
    FUTURE = "future"
    BEFORE_JOIN = "before_join"


class StreakDay(BaseModel):
    date: date
    status: DayStatus


class StreakCalendarResponse(BaseModel):
    streak: int
    first_join_date: date | None
    year: int
    month: int
    days: list[StreakDay]
