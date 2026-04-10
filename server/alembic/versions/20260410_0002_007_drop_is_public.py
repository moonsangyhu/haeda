"""drop is_public column and index from challenges

Revision ID: 007
Revises: 006
Create Date: 2026-04-10 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = "007"
down_revision: Union[str, None] = "006"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_index("idx_challenge_is_public", table_name="challenges")
    op.drop_column("challenges", "is_public")


def downgrade() -> None:
    op.add_column(
        "challenges",
        sa.Column("is_public", sa.Boolean(), nullable=False, server_default="false"),
    )
    op.create_index("idx_challenge_is_public", "challenges", ["is_public"])
