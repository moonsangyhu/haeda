"""
TDD tests for User.discriminator field.
Task 2+3: User 모델에 discriminator 컬럼 추가 + 마이그레이션 검증
"""
import uuid

import pytest
import pytest_asyncio
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User


class TestUserDiscriminatorField:
    """User 모델의 discriminator 필드 존재 및 제약 검증"""

    @pytest.mark.asyncio
    async def test_user_has_discriminator_field(self, db_session: AsyncSession):
        """Happy path: discriminator 필드로 User 생성 가능"""
        u = User(
            id=uuid.uuid4(),
            kakao_id=9991,
            nickname="테스터",
            discriminator="12345",
        )
        db_session.add(u)
        await db_session.commit()
        await db_session.refresh(u)

        assert u.discriminator == "12345"
        assert len(u.discriminator) == 5

    @pytest.mark.asyncio
    async def test_discriminator_is_required(self, db_session: AsyncSession):
        """Error path: discriminator 없이 생성 시 실패 (NOT NULL)"""
        from sqlalchemy.exc import IntegrityError

        u = User(
            id=uuid.uuid4(),
            kakao_id=9992,
            nickname="에러테스터",
            # discriminator intentionally omitted
        )
        db_session.add(u)
        with pytest.raises((IntegrityError, Exception)):
            await db_session.commit()

    @pytest.mark.asyncio
    async def test_same_nickname_different_discriminator(self, db_session: AsyncSession):
        """Happy path: 같은 닉네임 + 다른 discriminator 허용"""
        u1 = User(
            id=uuid.uuid4(),
            kakao_id=9993,
            nickname="홍길동",
            discriminator="11111",
        )
        u2 = User(
            id=uuid.uuid4(),
            kakao_id=9994,
            nickname="홍길동",
            discriminator="22222",
        )
        db_session.add(u1)
        db_session.add(u2)
        await db_session.commit()

        await db_session.refresh(u1)
        await db_session.refresh(u2)
        assert u1.nickname == u2.nickname
        assert u1.discriminator != u2.discriminator

    @pytest.mark.asyncio
    async def test_same_nickname_same_discriminator_rejected(self, db_session: AsyncSession):
        """Error path: 같은 닉네임 + 같은 discriminator 중복 거부"""
        from sqlalchemy.exc import IntegrityError

        u1 = User(
            id=uuid.uuid4(),
            kakao_id=9995,
            nickname="중복닉",
            discriminator="33333",
        )
        u2 = User(
            id=uuid.uuid4(),
            kakao_id=9996,
            nickname="중복닉",
            discriminator="33333",
        )
        db_session.add(u1)
        await db_session.commit()

        db_session.add(u2)
        with pytest.raises((IntegrityError, Exception)):
            await db_session.commit()

    @pytest.mark.asyncio
    async def test_discriminator_display_name(self, db_session: AsyncSession):
        """Happy path: 닉네임#discriminator 형식으로 표시 가능"""
        u = User(
            id=uuid.uuid4(),
            kakao_id=9997,
            nickname="플레이어",
            discriminator="54321",
        )
        db_session.add(u)
        await db_session.commit()
        await db_session.refresh(u)

        display_name = f"{u.nickname}#{u.discriminator}"
        assert display_name == "플레이어#54321"
