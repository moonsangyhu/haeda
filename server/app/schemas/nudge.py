import uuid
from datetime import date, datetime

from pydantic import BaseModel

from app.schemas.user import UserBrief


class NudgeSendRequest(BaseModel):
    receiver_id: uuid.UUID


class NudgeSendResponse(BaseModel):
    id: uuid.UUID
    challenge_id: uuid.UUID
    sender: UserBrief
    receiver_id: uuid.UUID
    date: date
    created_at: datetime

    model_config = {"from_attributes": True}
