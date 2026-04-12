import uuid
from datetime import datetime

from sqlalchemy import BigInteger, SmallInteger, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.models.base import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    kakao_id: Mapped[int] = mapped_column(BigInteger, unique=True, nullable=False)
    nickname: Mapped[str] = mapped_column(String(30), nullable=False)
    profile_image_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    background_color: Mapped[str | None] = mapped_column(String(9), nullable=True)
    day_cutoff_hour: Mapped[int] = mapped_column(SmallInteger, nullable=False, server_default="0")
    phone_number: Mapped[str | None] = mapped_column(String(20), nullable=True, unique=True)
    created_at: Mapped[datetime] = mapped_column(
        nullable=False, server_default=func.now()
    )

    # relationships
    created_challenges: Mapped[list["Challenge"]] = relationship(
        "Challenge", back_populates="creator", foreign_keys="Challenge.creator_id"
    )
    memberships: Mapped[list["ChallengeMember"]] = relationship(
        "ChallengeMember", back_populates="user"
    )
    verifications: Mapped[list["Verification"]] = relationship(
        "Verification", back_populates="user"
    )
    comments: Mapped[list["Comment"]] = relationship(
        "Comment", back_populates="author"
    )
    gem_transactions: Mapped[list["GemTransaction"]] = relationship(
        "GemTransaction", back_populates="user"
    )
    user_items: Mapped[list["UserItem"]] = relationship(
        "UserItem", back_populates="user"
    )
    character_equip: Mapped["CharacterEquip | None"] = relationship(
        "CharacterEquip", back_populates="user", uselist=False
    )
