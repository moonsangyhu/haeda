import uuid
from datetime import datetime

from sqlalchemy import ForeignKey, UniqueConstraint, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.models.base import Base


class RoomEquipMr(Base):
    """Mini-room decoration equipment for a user."""

    __tablename__ = "room_equip_mr"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), primary_key=True
    )
    wall_item_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("items.id"), nullable=True
    )
    ceiling_item_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("items.id"), nullable=True
    )
    window_item_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("items.id"), nullable=True
    )
    shelf_item_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("items.id"), nullable=True
    )
    plant_item_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("items.id"), nullable=True
    )
    desk_item_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("items.id"), nullable=True
    )
    rug_item_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("items.id"), nullable=True
    )
    floor_item_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("items.id"), nullable=True
    )
    updated_at: Mapped[datetime] = mapped_column(
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    # relationships
    user: Mapped["User"] = relationship("User", foreign_keys=[user_id])
    wall_item: Mapped["Item"] = relationship("Item", foreign_keys=[wall_item_id])
    ceiling_item: Mapped["Item"] = relationship("Item", foreign_keys=[ceiling_item_id])
    window_item: Mapped["Item"] = relationship("Item", foreign_keys=[window_item_id])
    shelf_item: Mapped["Item"] = relationship("Item", foreign_keys=[shelf_item_id])
    plant_item: Mapped["Item"] = relationship("Item", foreign_keys=[plant_item_id])
    desk_item: Mapped["Item"] = relationship("Item", foreign_keys=[desk_item_id])
    rug_item: Mapped["Item"] = relationship("Item", foreign_keys=[rug_item_id])
    floor_item: Mapped["Item"] = relationship("Item", foreign_keys=[floor_item_id])


class RoomEquipCr(Base):
    """Challenge room decoration equipment (shared by all members)."""

    __tablename__ = "room_equip_cr"

    challenge_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("challenges.id"), primary_key=True
    )
    wall_item_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("items.id"), nullable=True
    )
    window_item_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("items.id"), nullable=True
    )
    calendar_item_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("items.id"), nullable=True
    )
    board_item_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("items.id"), nullable=True
    )
    sofa_item_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("items.id"), nullable=True
    )
    floor_item_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("items.id"), nullable=True
    )
    updated_by_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )
    updated_at: Mapped[datetime] = mapped_column(
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    # relationships
    challenge: Mapped["Challenge"] = relationship("Challenge", foreign_keys=[challenge_id])
    wall_item: Mapped["Item"] = relationship("Item", foreign_keys=[wall_item_id])
    window_item: Mapped["Item"] = relationship("Item", foreign_keys=[window_item_id])
    calendar_item: Mapped["Item"] = relationship("Item", foreign_keys=[calendar_item_id])
    board_item: Mapped["Item"] = relationship("Item", foreign_keys=[board_item_id])
    sofa_item: Mapped["Item"] = relationship("Item", foreign_keys=[sofa_item_id])
    floor_item: Mapped["Item"] = relationship("Item", foreign_keys=[floor_item_id])
    updated_by_user: Mapped["User"] = relationship("User", foreign_keys=[updated_by_user_id])


class RoomEquipCrSignature(Base):
    """Per-member signature item in a challenge room."""

    __tablename__ = "room_equip_cr_signature"

    __table_args__ = (
        UniqueConstraint("challenge_id", "user_id", name="uq_room_equip_cr_signature_member"),
        Index("ix_room_equip_cr_signature_challenge", "challenge_id"),
        Index("ix_room_equip_cr_signature_user", "user_id"),
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
    signature_item_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("items.id"), nullable=True
    )
    updated_at: Mapped[datetime] = mapped_column(
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    # relationships
    challenge: Mapped["Challenge"] = relationship("Challenge", foreign_keys=[challenge_id])
    user: Mapped["User"] = relationship("User", foreign_keys=[user_id])
    signature_item: Mapped["Item"] = relationship("Item", foreign_keys=[signature_item_id])
