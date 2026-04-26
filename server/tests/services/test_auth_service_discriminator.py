import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.services.auth_service import login_or_register


@pytest.mark.asyncio
async def test_new_signup_assigns_discriminator(db_session: AsyncSession):
    user, is_new = await login_or_register(
        db_session,
        kakao_id=12345,
        nickname="신규유저",
        profile_image_url=None,
    )
    assert is_new is True
    assert user.discriminator is not None
    assert user.discriminator.isdigit()
    assert len(user.discriminator) == 5


@pytest.mark.asyncio
async def test_existing_user_keeps_discriminator(db_session: AsyncSession):
    existing = User(
        kakao_id=99999,
        nickname="기존",
        discriminator="42424",
    )
    db_session.add(existing)
    await db_session.commit()
    await db_session.refresh(existing)

    user, is_new = await login_or_register(
        db_session,
        kakao_id=99999,
        nickname="기존",
        profile_image_url=None,
    )
    assert is_new is False
    assert user.discriminator == "42424"


@pytest.mark.asyncio
async def test_two_users_same_nickname_get_different_discriminators(
    db_session: AsyncSession,
):
    u1, _ = await login_or_register(db_session, kakao_id=1, nickname="동명", profile_image_url=None)
    u2, _ = await login_or_register(db_session, kakao_id=2, nickname="동명", profile_image_url=None)
    assert u1.discriminator != u2.discriminator
