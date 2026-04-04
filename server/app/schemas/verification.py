import uuid
from datetime import date, datetime

from pydantic import BaseModel

from app.schemas.user import UserBrief


class VerificationCreateResponse(BaseModel):
    id: uuid.UUID
    date: date
    photo_url: str | None
    diary_text: str
    created_at: datetime
    day_completed: bool
    season_icon_type: str | None

    model_config = {"from_attributes": True}


class VerificationItem(BaseModel):
    id: uuid.UUID
    user: UserBrief
    photo_url: str | None
    diary_text: str
    comment_count: int
    created_at: datetime

    model_config = {"from_attributes": True}


class DailyVerificationsResponse(BaseModel):
    date: date
    all_completed: bool
    season_icon_type: str | None
    verifications: list[VerificationItem]
