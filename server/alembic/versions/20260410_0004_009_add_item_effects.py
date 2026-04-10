"""add effect_type and effect_value columns to items

Revision ID: 009
Revises: 008
Create Date: 2026-04-10 00:04:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "009"
down_revision: Union[str, None] = "008"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "items",
        sa.Column("effect_type", sa.String(30), nullable=True),
    )
    op.add_column(
        "items",
        sa.Column("effect_value", sa.Integer(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("items", "effect_value")
    op.drop_column("items", "effect_type")
