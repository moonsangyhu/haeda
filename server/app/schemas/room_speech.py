import uuid
from datetime import datetime

from pydantic import BaseModel


class RoomSpeechCreateRequest(BaseModel):
    content: str


class RoomSpeechItem(BaseModel):
    user_id: uuid.UUID
    nickname: str
    content: str
    created_at: datetime
    expires_at: datetime

    model_config = {"from_attributes": True}


class RoomSpeechSubmitResult(BaseModel):
    content: str
    created_at: datetime
    expires_at: datetime


class RoomSpeechDeleteResult(BaseModel):
    ok: bool = True
