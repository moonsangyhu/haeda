import uuid

from pydantic import BaseModel, Field


class UserSearchByIdRequest(BaseModel):
    nickname: str = Field(min_length=1, max_length=30)
    discriminator: str = Field(pattern=r"^[0-9]{5}$")


class UserSearchByIdResponse(BaseModel):
    user_id: uuid.UUID
    nickname: str
    discriminator: str
    profile_image_url: str | None
    friendship_status: str  # "none" | "pending" | "accepted" | "self"
