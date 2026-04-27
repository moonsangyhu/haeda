import uuid
from datetime import date, datetime

from sqlalchemy import Boolean, Date, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from app.models.base import Base


class UserTreasureState(Base):
    __tablename__ = "user_treasure_states"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id"),
        primary_key=True,
    )
    armed_date: Mapped[date] = mapped_column(Date, nullable=False)
    armed_at: Mapped[datetime] = mapped_column(nullable=False)
    opened: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="false"
    )
    updated_at: Mapped[datetime] = mapped_column(
        nullable=False, server_default=func.now()
    )
