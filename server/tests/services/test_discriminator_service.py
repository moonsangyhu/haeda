import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.services.discriminator_service import (
    DiscriminatorExhausted,
    generate_discriminator,
)


@pytest.mark.asyncio
async def test_generate_for_unused_nickname(db_session: AsyncSession):
    result = await generate_discriminator(db_session, nickname="첫사용자")
    assert result.isdigit()
    assert len(result) == 5
    assert 10000 <= int(result) <= 99999


@pytest.mark.asyncio
async def test_avoids_existing_discriminator(db_session: AsyncSession, monkeypatch):
    db_session.add(User(kakao_id=99001, nickname="중복", discriminator="10001"))
    await db_session.commit()

    sequence = iter(["10001", "10002"])
    monkeypatch.setattr(
        "app.services.discriminator_service._random_5digit",
        lambda: next(sequence),
    )

    result = await generate_discriminator(db_session, nickname="중복")
    assert result == "10002"


@pytest.mark.asyncio
async def test_raises_when_all_attempts_collide(db_session: AsyncSession, monkeypatch):
    db_session.add(User(kakao_id=99002, nickname="포화", discriminator="55555"))
    await db_session.commit()

    monkeypatch.setattr(
        "app.services.discriminator_service._random_5digit",
        lambda: "55555",
    )
    monkeypatch.setattr(
        "app.services.discriminator_service.MAX_ATTEMPTS", 3
    )

    with pytest.raises(DiscriminatorExhausted):
        await generate_discriminator(db_session, nickname="포화")
