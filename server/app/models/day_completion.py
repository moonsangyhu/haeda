import uuid
from datetime import date, datetime

from sqlalchemy import CheckConstraint, Date, ForeignKey, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.models.base import Base


class DayCompletion(Base):
    __tablename__ = "day_completions"

    __table_args__ = (
        UniqueConstraint("challenge_id", "date", name="uq_day_completion"),
        CheckConstraint(
            "season_icon_type IN ('spring', 'summer', 'fall', 'winter')",
            name="ck_season_icon_type",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    challenge_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("challenges.id"), nullable=False
    )
    date: Mapped[date] = mapped_column(Date, nullable=False)
    season_icon_type: Mapped[str] = mapped_column(String(10), nullable=False)
    completed_at: Mapped[datetime] = mapped_column(
        nullable=False, server_default=func.now()
    )

    # relationships
    challenge: Mapped["Challenge"] = relationship(
        "Challenge", back_populates="day_completions"
    )
