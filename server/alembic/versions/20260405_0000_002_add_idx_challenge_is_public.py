"""add idx_challenge_is_public index

Revision ID: 002
Revises: 001
Create Date: 2026-04-05 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "002"
down_revision: Union[str, None] = "001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # P1 인덱스: 공개 챌린지 탐색 (domain-model.md §3)
    op.create_index(
        "idx_challenge_is_public", "challenges", ["is_public"]
    )


def downgrade() -> None:
    op.drop_index("idx_challenge_is_public", table_name="challenges")
