import uuid
from datetime import datetime

from sqlalchemy import ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.models.base import Base


class CharacterEquip(Base):
    __tablename__ = "character_equips"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), primary_key=True
    )
    hat_item_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("items.id"), nullable=True
    )
    top_item_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("items.id"), nullable=True
    )
    bottom_item_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("items.id"), nullable=True
    )
    shoes_item_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("items.id"), nullable=True
    )
    accessory_item_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("items.id"), nullable=True
    )
    updated_at: Mapped[datetime] = mapped_column(
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    # relationships
    user: Mapped["User"] = relationship(
        "User", back_populates="character_equip", foreign_keys=[user_id]
    )
    hat: Mapped["Item"] = relationship(
        "Item", foreign_keys=[hat_item_id]
    )
    top: Mapped["Item"] = relationship(
        "Item", foreign_keys=[top_item_id]
    )
    bottom: Mapped["Item"] = relationship(
        "Item", foreign_keys=[bottom_item_id]
    )
    shoes: Mapped["Item"] = relationship(
        "Item", foreign_keys=[shoes_item_id]
    )
    accessory: Mapped["Item"] = relationship(
        "Item", foreign_keys=[accessory_item_id]
    )
