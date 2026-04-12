"""add day_cutoff_hour to users

Revision ID: 014
Revises: 013
Create Date: 2026-04-12 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "014"
down_revision: Union[str, None] = "013"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "day_cutoff_hour",
            sa.SmallInteger(),
            nullable=False,
            server_default="0",
        ),
    )
    op.create_check_constraint(
        "ck_users_day_cutoff_hour",
        "users",
        "day_cutoff_hour BETWEEN 0 AND 2",
    )


def downgrade() -> None:
    op.drop_constraint("ck_users_day_cutoff_hour", "users", type_="check")
    op.drop_column("users", "day_cutoff_hour")
