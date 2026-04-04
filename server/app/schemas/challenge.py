import uuid
from datetime import date, datetime

from pydantic import BaseModel

from app.schemas.user import UserBrief


class ChallengeListItem(BaseModel):
    id: uuid.UUID
    title: str
    category: str
    start_date: date
    end_date: date
    status: str
    member_count: int
    achievement_rate: float
    badge: str | None

    model_config = {"from_attributes": True}


class ChallengeDetail(BaseModel):
    id: uuid.UUID
    title: str
    description: str | None
    category: str
    start_date: date
    end_date: date
    verification_frequency: dict
    photo_required: bool
    is_public: bool
    invite_code: str
    status: str
    creator: UserBrief
    member_count: int
    is_member: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class DayEntry(BaseModel):
    date: date
    verified_members: list[uuid.UUID]
    all_completed: bool
    season_icon_type: str | None


class CalendarResponse(BaseModel):
    challenge_id: uuid.UUID
    year: int
    month: int
    members: list[UserBrief]
    days: list[DayEntry]
