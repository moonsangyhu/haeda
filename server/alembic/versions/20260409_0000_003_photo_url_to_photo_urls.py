"""photo_url to photo_urls (JSONB, max 3)

Revision ID: 003
Revises: 002
Create Date: 2026-04-09 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "003"
down_revision: Union[str, None] = "002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add photo_urls JSONB column
    op.add_column(
        "verifications",
        sa.Column("photo_urls", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    )

    # Migrate existing data: wrap photo_url in a list if not null
    op.execute(
        """
        UPDATE verifications
        SET photo_urls = to_jsonb(ARRAY[photo_url])
        WHERE photo_url IS NOT NULL
        """
    )

    # Drop old photo_url column
    op.drop_column("verifications", "photo_url")


def downgrade() -> None:
    # Add photo_url TEXT column back
    op.add_column(
        "verifications",
        sa.Column("photo_url", sa.Text(), nullable=True),
    )

    # Migrate data back: take first element of photo_urls array
    op.execute(
        """
        UPDATE verifications
        SET photo_url = photo_urls->>0
        WHERE photo_urls IS NOT NULL AND jsonb_array_length(photo_urls) > 0
        """
    )

    # Drop photo_urls column
    op.drop_column("verifications", "photo_urls")
