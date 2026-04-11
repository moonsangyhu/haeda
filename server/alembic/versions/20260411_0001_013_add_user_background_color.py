"""add background_color to users

Revision ID: 013
Revises: 012
Create Date: 2026-04-11 00:01:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "013"
down_revision: Union[str, None] = "012"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("background_color", sa.String(9), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("users", "background_color")
