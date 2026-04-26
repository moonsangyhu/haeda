"""add user.discriminator with backfill

Revision ID: 020
Revises: 019
Create Date: 2026-04-26 00:01:00.000000

"""
import random
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "020"
down_revision: Union[str, None] = "019"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1) NULLABLE 로 컬럼 추가
    op.add_column(
        "users",
        sa.Column("discriminator", sa.String(length=5), nullable=True),
    )

    # 2) 닉네임 그룹 단위로 백필
    bind = op.get_bind()
    rows = bind.execute(
        sa.text("SELECT id, nickname FROM users ORDER BY created_at")
    ).fetchall()

    used_per_nickname: dict[str, set[str]] = {}
    rng = random.Random(20260426)  # 결정성 확보 (재실행 시 동일 결과)
    for row in rows:
        nickname = row.nickname
        used = used_per_nickname.setdefault(nickname, set())
        for _ in range(50):
            candidate = f"{rng.randint(10000, 99999)}"
            if candidate not in used:
                used.add(candidate)
                bind.execute(
                    sa.text("UPDATE users SET discriminator = :d WHERE id = :id"),
                    {"d": candidate, "id": row.id},
                )
                break
        else:
            raise RuntimeError(
                f"Could not assign discriminator for nickname={nickname!r}"
            )

    # 3) NOT NULL + UNIQUE + CHECK 제약 추가
    op.alter_column("users", "discriminator", nullable=False)
    op.create_unique_constraint(
        "uq_users_nickname_discriminator",
        "users",
        ["nickname", "discriminator"],
    )
    op.create_check_constraint(
        "ck_users_discriminator_format",
        "users",
        "discriminator ~ '^[0-9]{5}$'",
    )


def downgrade() -> None:
    op.drop_constraint(
        "ck_users_discriminator_format", "users", type_="check"
    )
    op.drop_constraint(
        "uq_users_nickname_discriminator", "users", type_="unique"
    )
    op.drop_column("users", "discriminator")
