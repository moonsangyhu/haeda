import uuid
from datetime import date, datetime

from pydantic import BaseModel, Field

from app.schemas.character_schema import CharacterSlotBrief, MemberCharacter
from app.schemas.user import UserBrief


class CalendarMember(BaseModel):
    id: uuid.UUID
    nickname: str
    profile_image_url: str | None
    character: MemberCharacter


class ChallengeCreate(BaseModel):
    title: str
    description: str | None = None
    category: str
    start_date: date
    end_date: date
    verification_frequency: dict
    photo_required: bool = False
    day_cutoff_hour: int = 0
    icon: str = Field(default="🎯", max_length=8)


class ChallengeCreateResponse(BaseModel):
    id: uuid.UUID
    title: str
    description: str | None
    category: str
    start_date: date
    end_date: date
    verification_frequency: dict
    photo_required: bool
    day_cutoff_hour: int
    invite_code: str
    status: str
    creator: UserBrief
    member_count: int
    icon: str
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
    icon: str
    last_verified_at: datetime | None

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
    day_cutoff_hour: int
    invite_code: str
    status: str
    creator: UserBrief
    member_count: int
    is_member: bool
    is_creator: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class ChallengeSettingsUpdate(BaseModel):
    day_cutoff_hour: int | None = None


class ChallengeSettingsResponse(BaseModel):
    day_cutoff_hour: int


class DayEntry(BaseModel):
    date: date
    verified_members: list[uuid.UUID]
    all_completed: bool
    season_icon_type: str | None


class CalendarResponse(BaseModel):
    challenge_id: uuid.UUID
    year: int
    month: int
    members: list[CalendarMember]
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
