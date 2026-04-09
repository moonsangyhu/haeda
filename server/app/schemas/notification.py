import uuid
from datetime import datetime

from pydantic import BaseModel


class NotificationItem(BaseModel):
    id: uuid.UUID
    type: str
    title: str
    body: str
    data_json: dict | None
    is_read: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class NotificationListResponse(BaseModel):
    notifications: list[NotificationItem]
    unread_count: int
