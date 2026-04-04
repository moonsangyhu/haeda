"""initial schema

Revision ID: 001
Revises:
Create Date: 2026-04-04 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # --- users ---
    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("kakao_id", sa.BigInteger(), nullable=False),
        sa.Column("nickname", sa.String(30), nullable=False),
        sa.Column("profile_image_url", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.UniqueConstraint("kakao_id", name="uq_users_kakao_id"),
    )

    # --- challenges ---
    op.create_table(
        "challenges",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "creator_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column("title", sa.String(100), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("category", sa.String(50), nullable=False),
        sa.Column("start_date", sa.Date(), nullable=False),
        sa.Column("end_date", sa.Date(), nullable=False),
        sa.Column(
            "verification_frequency",
            postgresql.JSONB(),
            nullable=False,
            server_default=sa.text('\'{"type": "daily"}\''),
        ),
        sa.Column(
            "photo_required",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
        sa.Column("invite_code", sa.String(8), nullable=False),
        sa.Column(
            "is_public",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
        sa.Column(
            "status",
            sa.String(20),
            nullable=False,
            server_default=sa.text("'active'"),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.CheckConstraint("end_date > start_date", name="ck_challenge_date_range"),
        sa.CheckConstraint(
            "status IN ('active', 'completed')", name="ck_challenge_status"
        ),
        sa.UniqueConstraint("invite_code", name="uq_challenges_invite_code"),
    )

    # --- challenge_members ---
    op.create_table(
        "challenge_members",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "challenge_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("challenges.id"),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column(
            "joined_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column("badge", sa.String(20), nullable=True),
        sa.UniqueConstraint(
            "challenge_id", "user_id", name="uq_challenge_member"
        ),
    )

    # --- verifications ---
    op.create_table(
        "verifications",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "challenge_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("challenges.id"),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("photo_url", sa.Text(), nullable=True),
        sa.Column("diary_text", sa.Text(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.UniqueConstraint(
            "challenge_id", "user_id", "date", name="uq_verification_per_day"
        ),
    )

    # --- day_completions ---
    op.create_table(
        "day_completions",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "challenge_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("challenges.id"),
            nullable=False,
        ),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("season_icon_type", sa.String(10), nullable=False),
        sa.Column(
            "completed_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.CheckConstraint(
            "season_icon_type IN ('spring', 'summer', 'fall', 'winter')",
            name="ck_season_icon_type",
        ),
        sa.UniqueConstraint(
            "challenge_id", "date", name="uq_day_completion"
        ),
    )

    # --- comments ---
    op.create_table(
        "comments",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "verification_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("verifications.id"),
            nullable=False,
        ),
        sa.Column(
            "author_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column("content", sa.String(500), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
    )

    # --- P0 인덱스 (domain-model.md §3) ---
    op.create_index(
        "idx_challenge_status", "challenges", ["status"]
    )
    op.create_index(
        "idx_challenge_invite_code", "challenges", ["invite_code"]
    )
    op.create_index(
        "idx_member_user_id", "challenge_members", ["user_id"]
    )
    op.create_index(
        "idx_member_challenge_id", "challenge_members", ["challenge_id"]
    )
    op.create_index(
        "idx_verification_challenge_date", "verifications", ["challenge_id", "date"]
    )
    op.create_index(
        "idx_verification_user_challenge", "verifications", ["user_id", "challenge_id"]
    )
    op.create_index(
        "idx_day_completion_challenge", "day_completions", ["challenge_id"]
    )
    op.create_index(
        "idx_comment_verification", "comments", ["verification_id"]
    )


def downgrade() -> None:
    op.drop_index("idx_comment_verification", table_name="comments")
    op.drop_index("idx_day_completion_challenge", table_name="day_completions")
    op.drop_index("idx_verification_user_challenge", table_name="verifications")
    op.drop_index("idx_verification_challenge_date", table_name="verifications")
    op.drop_index("idx_member_challenge_id", table_name="challenge_members")
    op.drop_index("idx_member_user_id", table_name="challenge_members")
    op.drop_index("idx_challenge_invite_code", table_name="challenges")
    op.drop_index("idx_challenge_status", table_name="challenges")

    op.drop_table("comments")
    op.drop_table("day_completions")
    op.drop_table("verifications")
    op.drop_table("challenge_members")
    op.drop_table("challenges")
    op.drop_table("users")
