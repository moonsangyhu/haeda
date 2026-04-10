"""add items, user_items, and character_equips tables

Revision ID: 008
Revises: 007
Create Date: 2026-04-10 00:03:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

# revision identifiers, used by Alembic.
revision: str = "008"
down_revision: Union[str, None] = "007"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "items",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("name", sa.String(50), nullable=False),
        sa.Column("category", sa.String(20), nullable=False),
        sa.Column("price", sa.Integer(), nullable=False),
        sa.Column("rarity", sa.String(10), nullable=False),
        sa.Column("asset_key", sa.String(100), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.create_index("idx_items_category", "items", ["category"])
    op.create_index("idx_items_is_active", "items", ["is_active"])

    op.create_table(
        "user_items",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column(
            "item_id",
            UUID(as_uuid=True),
            sa.ForeignKey("items.id"),
            nullable=False,
        ),
        sa.Column(
            "purchased_at",
            sa.TIMESTAMP(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.UniqueConstraint("user_id", "item_id", name="uq_user_item"),
    )
    op.create_index("idx_user_items_user_id", "user_items", ["user_id"])

    op.create_table(
        "character_equips",
        sa.Column(
            "user_id",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            primary_key=True,
        ),
        sa.Column("hat_item_id", UUID(as_uuid=True), sa.ForeignKey("items.id"), nullable=True),
        sa.Column("top_item_id", UUID(as_uuid=True), sa.ForeignKey("items.id"), nullable=True),
        sa.Column("bottom_item_id", UUID(as_uuid=True), sa.ForeignKey("items.id"), nullable=True),
        sa.Column("shoes_item_id", UUID(as_uuid=True), sa.ForeignKey("items.id"), nullable=True),
        sa.Column("accessory_item_id", UUID(as_uuid=True), sa.ForeignKey("items.id"), nullable=True),
        sa.Column(
            "updated_at",
            sa.TIMESTAMP(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_table("character_equips")
    op.drop_index("idx_user_items_user_id", table_name="user_items")
    op.drop_table("user_items")
    op.drop_index("idx_items_is_active", table_name="items")
    op.drop_index("idx_items_category", table_name="items")
    op.drop_table("items")
