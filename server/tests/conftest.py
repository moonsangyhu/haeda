import uuid
from datetime import date

import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import JSON, event
from sqlalchemy.dialects.sqlite.base import SQLiteTypeCompiler
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

# SQLite 호환: JSONB → JSON 타입으로 컴파일 (테스트 환경 전용)
if not hasattr(SQLiteTypeCompiler, "visit_JSONB"):
    SQLiteTypeCompiler.visit_JSONB = SQLiteTypeCompiler.visit_JSON  # type: ignore[attr-defined]

from app.database import get_db  # noqa: E402
from app.main import app  # noqa: E402
from app.models.base import Base  # noqa: E402
from app.models.challenge import Challenge  # noqa: E402
from app.models.challenge_member import ChallengeMember  # noqa: E402
from app.models.day_completion import DayCompletion  # noqa: E402
from app.models.user import User  # noqa: E402
from app.models.verification import Verification  # noqa: E402

TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"


@pytest_asyncio.fixture(scope="function")
async def db_session():
    engine = create_async_engine(TEST_DATABASE_URL, echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
        autocommit=False,
        autoflush=False,
    )
    async with session_factory() as session:
        yield session

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()


@pytest_asyncio.fixture(scope="function")
async def client(db_session: AsyncSession):
    async def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as ac:
        yield ac
    app.dependency_overrides.clear()


# ---------- 공통 픽스처 ----------

@pytest_asyncio.fixture
async def user(db_session: AsyncSession) -> User:
    u = User(
        id=uuid.uuid4(),
        kakao_id=1001,
        nickname="테스터",
        discriminator="11111",
        profile_image_url=None,
    )
    db_session.add(u)
    await db_session.commit()
    await db_session.refresh(u)
    return u


@pytest_asyncio.fixture
async def other_user(db_session: AsyncSession) -> User:
    u = User(
        id=uuid.uuid4(),
        kakao_id=1002,
        nickname="다른사람",
        discriminator="22222",
        profile_image_url="https://example.com/img.jpg",
    )
    db_session.add(u)
    await db_session.commit()
    await db_session.refresh(u)
    return u


@pytest_asyncio.fixture
async def challenge(db_session: AsyncSession, user: User) -> Challenge:
    c = Challenge(
        id=uuid.uuid4(),
        creator_id=user.id,
        title="운동 30일",
        description="매일 30분 운동",
        category="운동",
        start_date=date(2026, 4, 1),
        end_date=date(2026, 4, 30),
        verification_frequency={"type": "daily"},
        photo_required=False,
        invite_code="ABCD1234",
        status="active",
    )
    db_session.add(c)
    await db_session.commit()
    await db_session.refresh(c)
    return c


@pytest_asyncio.fixture
async def membership(
    db_session: AsyncSession, challenge: Challenge, user: User
) -> ChallengeMember:
    m = ChallengeMember(
        id=uuid.uuid4(),
        challenge_id=challenge.id,
        user_id=user.id,
        badge=None,
    )
    db_session.add(m)
    await db_session.commit()
    await db_session.refresh(m)
    return m
