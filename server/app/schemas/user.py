import uuid

from pydantic import BaseModel


class UserBrief(BaseModel):
    id: uuid.UUID
    nickname: str
    profile_image_url: str | None

    model_config = {"from_attributes": True}
