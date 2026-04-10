"""add gem_transactions table

Revision ID: 006
Revises: 005
Create Date: 2026-04-10 00:01:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

# revision identifiers, used by Alembic.
revision: str = "006"
down_revision: Union[str, None] = "005"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "gem_transactions",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column("amount", sa.Integer(), nullable=False),
        sa.Column("reason", sa.String(50), nullable=False),
        sa.Column("reference_id", UUID(as_uuid=True), nullable=True),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.create_index(
        "idx_gem_tx_user_id",
        "gem_transactions",
        ["user_id"],
    )
    op.create_index(
        "idx_verification_user_date",
        "verifications",
        ["user_id", "date"],
    )


def downgrade() -> None:
    op.drop_index("idx_verification_user_date", table_name="verifications")
    op.drop_index("idx_gem_tx_user_id", table_name="gem_transactions")
    op.drop_table("gem_transactions")
