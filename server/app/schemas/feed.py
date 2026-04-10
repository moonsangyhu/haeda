import uuid
from datetime import datetime

from pydantic import BaseModel

from app.schemas.user import UserBrief


class FeedItemResponse(BaseModel):
    id: uuid.UUID
    actor: UserBrief
    type: str
    challenge_title: str
    challenge_id: uuid.UUID
    photo_urls: list[str] | None
    diary_text: str | None
    clap_count: int
    has_clapped: bool
    created_at: datetime


class FeedListResponse(BaseModel):
    items: list[FeedItemResponse]
    next_cursor: str | None


class ClapToggleResponse(BaseModel):
    clapped: bool
    clap_count: int
