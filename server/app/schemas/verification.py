import uuid
from datetime import date, datetime

from pydantic import BaseModel

from app.schemas.coin import CoinEarned
from app.schemas.comment import CommentItem
from app.schemas.user import UserBrief


class VerificationCreateResponse(BaseModel):
    id: uuid.UUID
    date: date
    photo_urls: list[str] | None
    diary_text: str
    created_at: datetime
    day_completed: bool
    season_icon_type: str | None
    coins_earned: list[CoinEarned] | None = None

    model_config = {"from_attributes": True}


class VerificationItem(BaseModel):
    id: uuid.UUID
    user: UserBrief
    photo_urls: list[str] | None
    diary_text: str
    comment_count: int = 0
    created_at: datetime

    model_config = {"from_attributes": True}


class DailyVerificationsResponse(BaseModel):
    date: date
    all_completed: bool
    season_icon_type: str | None
    verifications: list[VerificationItem]


class VerificationDetailResponse(BaseModel):
    id: uuid.UUID
    challenge_id: uuid.UUID
    user: UserBrief
    date: date
    photo_urls: list[str] | None
    diary_text: str
    comments: list[CommentItem]
    created_at: datetime

    model_config = {"from_attributes": True}
