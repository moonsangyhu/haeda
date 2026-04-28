"""add challenge.icon column

Revision ID: 023
Revises: 022
Create Date: 2026-04-28 00:01:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "023"
down_revision: Union[str, None] = "022"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # NOT NULL + server_default 로 기존 row 자동 backfill ('🎯').
    op.add_column(
        "challenges",
        sa.Column(
            "icon",
            sa.String(length=8),
            nullable=False,
            server_default=sa.text("'🎯'"),
        ),
    )


def downgrade() -> None:
    op.drop_column("challenges", "icon")
