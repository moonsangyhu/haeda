import uuid
from datetime import date, datetime

from pydantic import BaseModel

from app.schemas.user import UserBrief


class CommentAuthor(BaseModel):
    id: uuid.UUID
    nickname: str
    profile_image_url: str | None

    model_config = {"from_attributes": True}


class CommentItem(BaseModel):
    id: uuid.UUID
    author: CommentAuthor
    content: str
    created_at: datetime

    model_config = {"from_attributes": True}


class CommentCreateRequest(BaseModel):
    content: str


class CommentsListResponse(BaseModel):
    comments: list[CommentItem]
    next_cursor: str | None


class VerificationDetailResponse(BaseModel):
    id: uuid.UUID
    challenge_id: uuid.UUID
    user: UserBrief
    date: date
    photo_url: str | None
    diary_text: str
    comments: list[CommentItem]
    created_at: datetime
