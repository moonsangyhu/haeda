"""add phone_number to users and create friendships table

Revision ID: 010
Revises: 009
Create Date: 2026-04-10 00:05:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "010"
down_revision: Union[str, None] = "009"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add phone_number to users
    op.add_column(
        "users",
        sa.Column("phone_number", sa.String(20), nullable=True),
    )
    op.create_index(
        "ix_users_phone_number",
        "users",
        ["phone_number"],
        unique=True,
    )

    # Create friendships table
    op.create_table(
        "friendships",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            nullable=False,
        ),
        sa.Column(
            "requester_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column(
            "addressee_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column(
            "status",
            sa.String(20),
            nullable=False,
            server_default="pending",
        ),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "accepted_at",
            sa.TIMESTAMP(timezone=True),
            nullable=True,
        ),
        sa.UniqueConstraint("requester_id", "addressee_id", name="uq_friendship_pair"),
        sa.CheckConstraint("requester_id != addressee_id", name="ck_no_self_friend"),
    )
    op.create_index(
        "idx_friendship_addressee_status",
        "friendships",
        ["addressee_id", "status"],
    )
    op.create_index(
        "idx_friendship_requester_status",
        "friendships",
        ["requester_id", "status"],
    )


def downgrade() -> None:
    op.drop_index("idx_friendship_requester_status", table_name="friendships")
    op.drop_index("idx_friendship_addressee_status", table_name="friendships")
    op.drop_table("friendships")
    op.drop_index("ix_users_phone_number", table_name="users")
    op.drop_column("users", "phone_number")
