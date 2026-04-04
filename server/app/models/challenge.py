import uuid
from datetime import date, datetime

from sqlalchemy import Boolean, CheckConstraint, Date, ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.models.base import Base


class Challenge(Base):
    __tablename__ = "challenges"

    __table_args__ = (
        CheckConstraint("end_date > start_date", name="ck_challenge_date_range"),
        CheckConstraint(
            "status IN ('active', 'completed')", name="ck_challenge_status"
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    creator_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )
    title: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    category: Mapped[str] = mapped_column(String(50), nullable=False)
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date] = mapped_column(Date, nullable=False)
    verification_frequency: Mapped[dict] = mapped_column(
        JSONB, nullable=False, server_default='{"type": "daily"}'
    )
    photo_required: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )
    invite_code: Mapped[str] = mapped_column(String(8), unique=True, nullable=False)
    is_public: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="active", server_default="active"
    )
    created_at: Mapped[datetime] = mapped_column(
        nullable=False, server_default=func.now()
    )

    # relationships
    creator: Mapped["User"] = relationship(
        "User", back_populates="created_challenges", foreign_keys=[creator_id]
    )
    members: Mapped[list["ChallengeMember"]] = relationship(
        "ChallengeMember", back_populates="challenge"
    )
    verifications: Mapped[list["Verification"]] = relationship(
        "Verification", back_populates="challenge"
    )
    day_completions: Mapped[list["DayCompletion"]] = relationship(
        "DayCompletion", back_populates="challenge"
    )
