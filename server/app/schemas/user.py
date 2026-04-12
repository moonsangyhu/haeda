import uuid

from pydantic import BaseModel, Field

from app.schemas.character_schema import MemberCharacter


class UserBrief(BaseModel):
    id: uuid.UUID
    nickname: str
    profile_image_url: str | None
    background_color: str | None = None
    character: MemberCharacter | None = None

    model_config = {"from_attributes": True}


class KakaoLoginRequest(BaseModel):
    kakao_access_token: str


class UserWithIsNew(BaseModel):
    id: uuid.UUID
    nickname: str | None
    profile_image_url: str | None
    background_color: str | None = None
    day_cutoff_hour: int = 0
    is_new: bool


class AuthLoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    user: UserWithIsNew


class ProfileUpdateResponse(BaseModel):
    id: uuid.UUID
    nickname: str
    profile_image_url: str | None
    background_color: str | None = None
    day_cutoff_hour: int = 0


class ProfileUpdateRequest(BaseModel):
    day_cutoff_hour: int | None = Field(default=None, ge=0, le=2)


class UserStatsResponse(BaseModel):
    streak: int
    verified_today: bool
    active_challenges: int
    completed_challenges: int
    gems: int
