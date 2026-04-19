import uuid
from datetime import datetime

from sqlalchemy import TIMESTAMP, ForeignKey, Index, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.models.base import Base


class RoomSpeech(Base):
    __tablename__ = "room_speeches"
    __table_args__ = (
        UniqueConstraint("challenge_id", "user_id", name="uq_room_speeches_member"),
        Index("ix_room_speeches_challenge_expires", "challenge_id", "expires_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    challenge_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("challenges.id"), nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    content: Mapped[str] = mapped_column(String(40), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default=func.now()
    )
    expires_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False
    )

    challenge: Mapped["Challenge"] = relationship("Challenge")
    user: Mapped["User"] = relationship("User")
