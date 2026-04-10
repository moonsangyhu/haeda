import uuid
from datetime import datetime

from sqlalchemy import ForeignKey, Index, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.models.base import Base


class FeedItem(Base):
    __tablename__ = "feed_items"

    __table_args__ = (
        Index("idx_feed_item_actor_created", "actor_id", "created_at"),
        Index("idx_feed_item_created", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    actor_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False
    )
    type: Mapped[str] = mapped_column(String(30), nullable=False)
    reference_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False
    )
    challenge_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("challenges.id"), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        nullable=False, server_default=func.now()
    )

    # relationships
    actor: Mapped["User"] = relationship("User", foreign_keys=[actor_id])
    challenge: Mapped["Challenge"] = relationship("Challenge", foreign_keys=[challenge_id])
    claps: Mapped[list["Clap"]] = relationship("Clap", back_populates="feed_item")
