import uuid
from datetime import date, datetime

from pydantic import BaseModel

from app.schemas.user import UserBrief


class ChallengeCreate(BaseModel):
    title: str
    description: str | None = None
    category: str
    start_date: date
    end_date: date
    verification_frequency: dict
    photo_required: bool = False


class ChallengeCreateResponse(BaseModel):
    id: uuid.UUID
    title: str
    description: str | None
    category: str
    start_date: date
    end_date: date
    verification_frequency: dict
    photo_required: bool
    invite_code: str
    status: str
    creator: UserBrief
    member_count: int
    created_at: datetime

    model_config = {"from_attributes": True}


class JoinResponse(BaseModel):
    challenge_id: uuid.UUID
    joined_at: datetime


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
    today_verified: bool

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


# --- Completion (Flow 8) ---


class CompletionMyResult(BaseModel):
    user_id: uuid.UUID
    achievement_rate: float
    verified_days: int
    expected_days: int
    badge: str | None


class CompletionMember(BaseModel):
    user_id: uuid.UUID
    nickname: str
    profile_image_url: str | None
    achievement_rate: float
    verified_days: int
    badge: str | None


class CompletionCalendarSummary(BaseModel):
    total_days: int
    all_completed_days: int
    season_icon_types: list[str]


class CompletionResponse(BaseModel):
    challenge_id: uuid.UUID
    title: str
    category: str
    start_date: date
    end_date: date
    total_days: int
    my_result: CompletionMyResult
    members: list[CompletionMember]
    day_completions: int
    calendar_summary: CompletionCalendarSummary
