"""add challenge icon change history columns

Revision ID: 024
Revises: 023
Create Date: 2026-05-30 00:01:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "024"
down_revision: Union[str, None] = "023"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "challenges",
        sa.Column("previous_icon", sa.String(length=8), nullable=True),
    )
    op.add_column(
        "challenges",
        sa.Column(
            "icon_changed_at",
            sa.TIMESTAMP(timezone=True),
            nullable=True,
        ),
    )
    op.add_column(
        "challenges",
        sa.Column(
            "icon_changed_by_user_id",
            sa.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )


def downgrade() -> None:
    op.drop_column("challenges", "icon_changed_by_user_id")
    op.drop_column("challenges", "icon_changed_at")
    op.drop_column("challenges", "previous_icon")
