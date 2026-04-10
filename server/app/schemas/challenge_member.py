from pydantic import BaseModel


class MemberSettingsUpdate(BaseModel):
    notify_streak: bool


class MemberSettingsResponse(BaseModel):
    notify_streak: bool
