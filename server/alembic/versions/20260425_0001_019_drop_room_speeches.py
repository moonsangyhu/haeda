"""drop room_speeches table

Revision ID: 019
Revises: 018
Create Date: 2026-04-25 00:01:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "019"
down_revision: Union[str, None] = "018"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_index("ix_room_speeches_challenge_expires", table_name="room_speeches")
    op.drop_constraint("uq_room_speeches_member", "room_speeches", type_="unique")
    op.drop_table("room_speeches")


def downgrade() -> None:
    op.create_table(
        "room_speeches",
        sa.Column("id", sa.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "challenge_id",
            sa.UUID(as_uuid=True),
            sa.ForeignKey("challenges.id"),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            sa.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column("content", sa.String(40), nullable=False),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column("expires_at", sa.TIMESTAMP(timezone=True), nullable=False),
    )
    op.create_unique_constraint(
        "uq_room_speeches_member", "room_speeches", ["challenge_id", "user_id"]
    )
    op.create_index(
        "ix_room_speeches_challenge_expires",
        "room_speeches",
        ["challenge_id", "expires_at"],
    )
