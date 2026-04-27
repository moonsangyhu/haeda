import uuid
from datetime import datetime

from pydantic import BaseModel

from app.schemas.character_schema import MemberCharacter


class CommentAuthor(BaseModel):
    id: uuid.UUID
    nickname: str
    profile_image_url: str | None
    character: MemberCharacter | None = None

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
