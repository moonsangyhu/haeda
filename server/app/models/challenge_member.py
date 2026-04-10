import uuid
from datetime import datetime

from sqlalchemy import Boolean, ForeignKey, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.models.base import Base


class ChallengeMember(Base):
    __tablename__ = "challenge_members"

    __table_args__ = (
        UniqueConstraint("challenge_id", "user_id", name="uq_challenge_member"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    challenge_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("challenges.id"), nullable=False
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )
    joined_at: Mapped[datetime] = mapped_column(
        nullable=False, server_default=func.now()
    )
    badge: Mapped[str | None] = mapped_column(String(20), nullable=True)
    notify_streak: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="true"
    )

    # relationships
    challenge: Mapped["Challenge"] = relationship(
        "Challenge", back_populates="members"
    )
    user: Mapped["User"] = relationship(
        "User", back_populates="memberships"
    )
