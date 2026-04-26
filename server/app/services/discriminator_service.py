import random

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User


MAX_ATTEMPTS = 50


class DiscriminatorExhausted(Exception):
    """닉네임 그룹 내에서 사용 가능한 discriminator 를 찾지 못함."""


def _random_5digit() -> str:
    return f"{random.randint(10000, 99999)}"


async def generate_discriminator(db: AsyncSession, *, nickname: str) -> str:
    used_stmt = select(User.discriminator).where(User.nickname == nickname)
    used_result = await db.execute(used_stmt)
    used: set[str] = {row[0] for row in used_result.all()}

    for _ in range(MAX_ATTEMPTS):
        candidate = _random_5digit()
        if candidate not in used:
            return candidate

    raise DiscriminatorExhausted(
        f"닉네임 '{nickname}' 에서 가용 discriminator 를 찾지 못함"
    )
