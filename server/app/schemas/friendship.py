import uuid
from datetime import datetime

from pydantic import BaseModel

from app.schemas.user import UserBrief


class FriendRequestCreate(BaseModel):
    addressee_id: uuid.UUID


class FriendshipResponse(BaseModel):
    id: uuid.UUID
    requester_id: uuid.UUID
    addressee_id: uuid.UUID
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class FriendItem(BaseModel):
    user_id: uuid.UUID
    nickname: str
    profile_image_url: str | None


class FriendListResponse(BaseModel):
    friends: list[FriendItem]


class FriendRequestItem(BaseModel):
    id: uuid.UUID
    user: UserBrief
    created_at: datetime


class PendingRequestsResponse(BaseModel):
    requests: list[FriendRequestItem]


class ContactMatchRequest(BaseModel):
    phone_numbers: list[str]


class ContactMatchItem(BaseModel):
    user_id: uuid.UUID
    nickname: str
    profile_image_url: str | None
    friendship_status: str | None  # null, 'pending', 'accepted'


class ContactMatchResponse(BaseModel):
    matches: list[ContactMatchItem]
