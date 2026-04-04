import uuid
from datetime import date, datetime

from sqlalchemy import Date, ForeignKey, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.models.base import Base


class Verification(Base):
    __tablename__ = "verifications"

    __table_args__ = (
        UniqueConstraint(
            "challenge_id", "user_id", "date", name="uq_verification_per_day"
        ),
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
    date: Mapped[date] = mapped_column(Date, nullable=False)
    photo_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    diary_text: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        nullable=False, server_default=func.now()
    )

    # relationships
    challenge: Mapped["Challenge"] = relationship(
        "Challenge", back_populates="verifications"
    )
    user: Mapped["User"] = relationship(
        "User", back_populates="verifications"
    )
    comments: Mapped[list["Comment"]] = relationship(
        "Comment", back_populates="verification"
    )
