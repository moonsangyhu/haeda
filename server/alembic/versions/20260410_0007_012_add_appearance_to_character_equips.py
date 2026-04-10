"""add skin_tone, eye_style, hair_style to character_equips

Revision ID: 012
Revises: 011
Create Date: 2026-04-10 00:07:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "012"
down_revision: Union[str, None] = "011"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "character_equips",
        sa.Column(
            "skin_tone",
            sa.String(20),
            nullable=False,
            server_default="fair",
        ),
    )
    op.add_column(
        "character_equips",
        sa.Column(
            "eye_style",
            sa.String(20),
            nullable=False,
            server_default="round",
        ),
    )
    op.add_column(
        "character_equips",
        sa.Column(
            "hair_style",
            sa.String(20),
            nullable=False,
            server_default="short",
        ),
    )


def downgrade() -> None:
    op.drop_column("character_equips", "hair_style")
    op.drop_column("character_equips", "eye_style")
    op.drop_column("character_equips", "skin_tone")
