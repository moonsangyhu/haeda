"""add feed_items and claps tables

Revision ID: 011
Revises: 010
Create Date: 2026-04-10 00:06:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "011"
down_revision: Union[str, None] = "010"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "feed_items",
        sa.Column("id", sa.dialects.postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "actor_id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column("type", sa.String(30), nullable=False),
        sa.Column(
            "reference_id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            nullable=False,
        ),
        sa.Column(
            "challenge_id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            sa.ForeignKey("challenges.id"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index("idx_feed_item_actor_created", "feed_items", ["actor_id", "created_at"])
    op.create_index("idx_feed_item_created", "feed_items", ["created_at"])

    op.create_table(
        "claps",
        sa.Column("id", sa.dialects.postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "feed_item_id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            sa.ForeignKey("feed_items.id"),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            sa.dialects.postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint("feed_item_id", "user_id", name="uq_clap_per_user"),
    )
    op.create_index("idx_clap_feed_item", "claps", ["feed_item_id"])


def downgrade() -> None:
    op.drop_index("idx_clap_feed_item", table_name="claps")
    op.drop_table("claps")
    op.drop_index("idx_feed_item_created", table_name="feed_items")
    op.drop_index("idx_feed_item_actor_created", table_name="feed_items")
    op.drop_table("feed_items")
