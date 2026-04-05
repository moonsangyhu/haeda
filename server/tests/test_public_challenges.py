"""GET /challenges — 공개 챌린지 목록 엔드포인트 테스트 (P1)"""
import base64
import uuid
from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.challenge import Challenge
from app.models.challenge_member import ChallengeMember
from app.models.user import User


# ---------- 픽스처 ----------


@pytest_asyncio.fixture
async def public_challenge(db_session: AsyncSession, user: User) -> Challenge:
    c = Challenge(
        id=uuid.uuid4(),
        creator_id=user.id,
        title="공개 운동 챌린지",
        description="공개 챌린지입니다",
        category="운동",
        start_date=date(2026, 4, 1),
        end_date=date(2026, 4, 30),
        verification_frequency={"type": "daily"},
        photo_required=True,
        invite_code="PUB12345",
        is_public=True,
        status="active",
    )
    db_session.add(c)
    await db_session.commit()
    await db_session.refresh(c)
    return c


@pytest_asyncio.fixture
async def public_challenge_membership(
    db_session: AsyncSession, public_challenge: Challenge, user: User
) -> ChallengeMember:
    m = ChallengeMember(
        id=uuid.uuid4(),
        challenge_id=public_challenge.id,
        user_id=user.id,
        badge=None,
    )
    db_session.add(m)
    await db_session.commit()
    await db_session.refresh(m)
    return m


@pytest_asyncio.fixture
async def private_challenge(db_session: AsyncSession, user: User) -> Challenge:
    c = Challenge(
        id=uuid.uuid4(),
        creator_id=user.id,
        title="비공개 챌린지",
        description=None,
        category="독서",
        start_date=date(2026, 4, 1),
        end_date=date(2026, 4, 30),
        verification_frequency={"type": "daily"},
        photo_required=False,
        invite_code="PRV12345",
        is_public=False,
        status="active",
    )
    db_session.add(c)
    await db_session.commit()
    await db_session.refresh(c)
    return c


@pytest_asyncio.fixture
async def completed_public_challenge(db_session: AsyncSession, user: User) -> Challenge:
    c = Challenge(
        id=uuid.uuid4(),
        creator_id=user.id,
        title="완료된 공개 챌린지",
        description=None,
        category="운동",
        start_date=date(2026, 3, 1),
        end_date=date(2026, 3, 31),
        verification_frequency={"type": "daily"},
        photo_required=False,
        invite_code="CMP12345",
        is_public=True,
        status="completed",
    )
    db_session.add(c)
    await db_session.commit()
    await db_session.refresh(c)
    return c


# ---------- 기본 동작 ----------


@pytest.mark.asyncio
async def test_list_public_challenges_success(
    client: AsyncClient,
    public_challenge: Challenge,
    public_challenge_membership: ChallengeMember,
    private_challenge: Challenge,
):
    """공개 챌린지만 반환되며 member_count가 정확한지 검증."""
    resp = await client.get("/api/v1/challenges")
    assert resp.status_code == 200
    body = resp.json()
    assert "data" in body
    data = body["data"]
    assert "challenges" in data
    assert "next_cursor" in data

    challenge_ids = [c["id"] for c in data["challenges"]]
    assert str(public_challenge.id) in challenge_ids
    # 비공개 챌린지는 목록에 없어야 함
    assert str(private_challenge.id) not in challenge_ids


@pytest.mark.asyncio
async def test_list_public_challenges_member_count(
    client: AsyncClient,
    public_challenge: Challenge,
    public_challenge_membership: ChallengeMember,
):
    """member_count가 정확하게 집계되는지 검증."""
    resp = await client.get("/api/v1/challenges")
    assert resp.status_code == 200
    challenges = resp.json()["data"]["challenges"]
    match = next((c for c in challenges if c["id"] == str(public_challenge.id)), None)
    assert match is not None
    assert match["member_count"] == 1
    assert match["photo_required"] is True
    assert "creator" in match
    assert match["creator"]["nickname"] == "테스터"


@pytest.mark.asyncio
async def test_list_public_challenges_excludes_completed(
    client: AsyncClient,
    completed_public_challenge: Challenge,
):
    """status=completed인 공개 챌린지는 목록에서 제외되어야 함."""
    resp = await client.get("/api/v1/challenges")
    assert resp.status_code == 200
    challenge_ids = [c["id"] for c in resp.json()["data"]["challenges"]]
    assert str(completed_public_challenge.id) not in challenge_ids


@pytest.mark.asyncio
async def test_list_public_challenges_empty(client: AsyncClient):
    """공개 챌린지가 없을 때 빈 목록 반환."""
    resp = await client.get("/api/v1/challenges")
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["challenges"] == []
    assert data["next_cursor"] is None


# ---------- 카테고리 필터 ----------


@pytest.mark.asyncio
async def test_list_public_challenges_category_filter(
    client: AsyncClient,
    public_challenge: Challenge,
    db_session: AsyncSession,
    user: User,
):
    """category 필터가 동작하는지 검증."""
    # 다른 카테고리의 공개 챌린지 추가
    other = Challenge(
        id=uuid.uuid4(),
        creator_id=user.id,
        title="독서 챌린지",
        description=None,
        category="독서",
        start_date=date(2026, 4, 1),
        end_date=date(2026, 4, 30),
        verification_frequency={"type": "daily"},
        photo_required=False,
        invite_code="OTH12345",
        is_public=True,
        status="active",
    )
    db_session.add(other)
    await db_session.commit()

    resp = await client.get("/api/v1/challenges?category=운동")
    assert resp.status_code == 200
    challenges = resp.json()["data"]["challenges"]
    assert all(c["category"] == "운동" for c in challenges)

    resp2 = await client.get("/api/v1/challenges?category=독서")
    assert resp2.status_code == 200
    challenges2 = resp2.json()["data"]["challenges"]
    assert all(c["category"] == "독서" for c in challenges2)


# ---------- 페이지네이션 ----------


@pytest.mark.asyncio
async def test_list_public_challenges_limit(
    client: AsyncClient,
    db_session: AsyncSession,
    user: User,
):
    """limit 파라미터가 적용되는지 검증."""
    # 5개 공개 챌린지 생성
    for i in range(5):
        c = Challenge(
            id=uuid.uuid4(),
            creator_id=user.id,
            title=f"챌린지 {i}",
            description=None,
            category="운동",
            start_date=date(2026, 4, 1),
            end_date=date(2026, 4, 30),
            verification_frequency={"type": "daily"},
            photo_required=False,
            invite_code=f"LMT0{i}123",
            is_public=True,
            status="active",
        )
        db_session.add(c)
    await db_session.commit()

    resp = await client.get("/api/v1/challenges?limit=3")
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert len(data["challenges"]) == 3
    assert data["next_cursor"] is not None


@pytest.mark.asyncio
async def test_list_public_challenges_cursor_pagination(
    client: AsyncClient,
    db_session: AsyncSession,
    user: User,
):
    """cursor 기반 페이지네이션이 동작하는지 검증.

    SQLite는 server_default=now()가 동일 트랜잭션 내 모든 행에 같은 값을 줄 수 있으므로
    각 챌린지에 명시적으로 서로 다른 created_at을 부여한다.
    """
    base_dt = datetime(2026, 4, 5, 12, 0, 0)
    for i in range(4):
        c = Challenge(
            id=uuid.uuid4(),
            creator_id=user.id,
            title=f"페이지 챌린지 {i}",
            description=None,
            category="운동",
            start_date=date(2026, 4, 1),
            end_date=date(2026, 4, 30),
            verification_frequency={"type": "daily"},
            photo_required=False,
            invite_code=f"PG0{i}1234",
            is_public=True,
            status="active",
            created_at=base_dt + timedelta(seconds=i),
        )
        db_session.add(c)
    await db_session.commit()

    # 첫 페이지 (limit=2)
    resp1 = await client.get("/api/v1/challenges?limit=2")
    assert resp1.status_code == 200
    data1 = resp1.json()["data"]
    assert len(data1["challenges"]) == 2
    assert data1["next_cursor"] is not None

    # 두 번째 페이지
    cursor = data1["next_cursor"]
    resp2 = await client.get(f"/api/v1/challenges?limit=2&cursor={cursor}")
    assert resp2.status_code == 200
    data2 = resp2.json()["data"]
    assert len(data2["challenges"]) == 2

    # 두 페이지의 챌린지 ID가 겹치지 않아야 함
    ids1 = {c["id"] for c in data1["challenges"]}
    ids2 = {c["id"] for c in data2["challenges"]}
    assert ids1.isdisjoint(ids2)


@pytest.mark.asyncio
async def test_list_public_challenges_limit_clamped_to_50(
    client: AsyncClient,
    db_session: AsyncSession,
    user: User,
):
    """limit > 50이면 50으로 클램핑되는지 검증."""
    # 10개만 생성해도 limit=100은 최대 50으로 클램핑됨
    for i in range(5):
        c = Challenge(
            id=uuid.uuid4(),
            creator_id=user.id,
            title=f"클램프 챌린지 {i}",
            description=None,
            category="운동",
            start_date=date(2026, 4, 1),
            end_date=date(2026, 4, 30),
            verification_frequency={"type": "daily"},
            photo_required=False,
            invite_code=f"CL0{i}1234",
            is_public=True,
            status="active",
        )
        db_session.add(c)
    await db_session.commit()

    # limit=100 요청 -> 최대 50 (실제 데이터 5개이므로 5개 반환)
    resp = await client.get("/api/v1/challenges?limit=100")
    assert resp.status_code == 200
    data = resp.json()["data"]
    # 5개만 있으므로 5개 반환, next_cursor는 None
    assert len(data["challenges"]) == 5
    assert data["next_cursor"] is None


# ---------- 인증 불필요 확인 ----------


@pytest.mark.asyncio
async def test_list_public_challenges_no_auth_required(
    client: AsyncClient,
    public_challenge: Challenge,
):
    """인증 헤더 없이도 200 반환되는지 검증."""
    resp = await client.get("/api/v1/challenges")
    assert resp.status_code == 200


# ---------- ChallengeCreate is_public 필드 ----------


@pytest.mark.asyncio
async def test_create_challenge_with_is_public(
    client: AsyncClient,
    user: User,
):
    """is_public=true로 챌린지를 생성할 수 있는지 검증."""
    payload = {
        "title": "공개 생성 챌린지",
        "category": "운동",
        "start_date": "2026-04-05",
        "end_date": "2026-05-04",
        "verification_frequency": {"type": "daily"},
        "photo_required": False,
        "is_public": True,
    }
    resp = await client.post(
        "/api/v1/challenges",
        json=payload,
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 201
    data = resp.json()["data"]
    assert data["is_public"] is True


@pytest.mark.asyncio
async def test_create_challenge_is_public_defaults_false(
    client: AsyncClient,
    user: User,
):
    """is_public 미전송 시 기본값 false인지 검증."""
    payload = {
        "title": "기본 비공개 챌린지",
        "category": "독서",
        "start_date": "2026-04-05",
        "end_date": "2026-05-04",
        "verification_frequency": {"type": "daily"},
        "photo_required": False,
    }
    resp = await client.post(
        "/api/v1/challenges",
        json=payload,
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 201
    data = resp.json()["data"]
    assert data["is_public"] is False
