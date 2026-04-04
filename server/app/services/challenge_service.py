import math
import random
import string
import uuid
from datetime import date

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.exceptions import AppException
from app.models.challenge import Challenge
from app.models.challenge_member import ChallengeMember
from app.models.user import User
from app.models.verification import Verification
from app.schemas.challenge import (
    ChallengeCreate,
    ChallengeCreateResponse,
    ChallengeDetail,
    ChallengeListItem,
    JoinResponse,
)
from app.schemas.user import UserBrief


def _generate_invite_code() -> str:
    chars = string.ascii_uppercase + string.digits
    return "".join(random.choices(chars, k=8))


def _compute_achievement_rate(
    verified_count: int,
    start_date: date,
    end_date: date,
    frequency: dict,
) -> float:
    total_days = (end_date - start_date).days + 1
    freq_type = frequency.get("type", "daily")
    if freq_type == "daily":
        expected = total_days
    else:
        times_per_week = frequency.get("times_per_week", 1)
        expected = math.ceil(total_days / 7) * times_per_week

    if expected == 0:
        return 0.0
    return round(verified_count / expected * 100, 1)


async def get_my_challenges(
    db: AsyncSession,
    user_id: uuid.UUID,
    status_filter: str | None,
) -> list[ChallengeListItem]:
    # 내가 속한 멤버십 + 챌린지 조회
    stmt = (
        select(ChallengeMember, Challenge)
        .join(Challenge, ChallengeMember.challenge_id == Challenge.id)
        .where(ChallengeMember.user_id == user_id)
    )
    if status_filter:
        stmt = stmt.where(Challenge.status == status_filter)

    result = await db.execute(stmt)
    rows = result.all()

    if not rows:
        return []

    challenge_ids = [row.Challenge.id for row in rows]

    # member_count: 챌린지별 멤버 수
    member_count_stmt = (
        select(ChallengeMember.challenge_id, func.count(ChallengeMember.id).label("cnt"))
        .where(ChallengeMember.challenge_id.in_(challenge_ids))
        .group_by(ChallengeMember.challenge_id)
    )
    member_count_result = await db.execute(member_count_stmt)
    member_count_map: dict[uuid.UUID, int] = {
        row.challenge_id: row.cnt for row in member_count_result
    }

    # verification_count: 내가 챌린지별로 인증한 횟수
    verification_count_stmt = (
        select(Verification.challenge_id, func.count(Verification.id).label("cnt"))
        .where(
            Verification.user_id == user_id,
            Verification.challenge_id.in_(challenge_ids),
        )
        .group_by(Verification.challenge_id)
    )
    verification_count_result = await db.execute(verification_count_stmt)
    verification_count_map: dict[uuid.UUID, int] = {
        row.challenge_id: row.cnt for row in verification_count_result
    }

    items: list[ChallengeListItem] = []
    for row in rows:
        challenge = row.Challenge
        membership = row.ChallengeMember
        verified_count = verification_count_map.get(challenge.id, 0)
        achievement_rate = _compute_achievement_rate(
            verified_count,
            challenge.start_date,
            challenge.end_date,
            challenge.verification_frequency,
        )
        items.append(
            ChallengeListItem(
                id=challenge.id,
                title=challenge.title,
                category=challenge.category,
                start_date=challenge.start_date,
                end_date=challenge.end_date,
                status=challenge.status,
                member_count=member_count_map.get(challenge.id, 0),
                achievement_rate=achievement_rate,
                badge=membership.badge,
            )
        )
    return items


async def get_challenge_detail(
    db: AsyncSession,
    challenge_id: uuid.UUID,
    user_id: uuid.UUID,
) -> ChallengeDetail:
    # Challenge + creator 조회
    stmt = (
        select(Challenge, User)
        .join(User, Challenge.creator_id == User.id)
        .where(Challenge.id == challenge_id)
    )
    result = await db.execute(stmt)
    row = result.first()
    if row is None:
        raise AppException(
            status_code=404,
            code="CHALLENGE_NOT_FOUND",
            message="챌린지를 찾을 수 없습니다.",
        )

    challenge, creator = row.Challenge, row.User

    # member_count
    member_count_stmt = select(func.count(ChallengeMember.id)).where(
        ChallengeMember.challenge_id == challenge_id
    )
    member_count_result = await db.execute(member_count_stmt)
    member_count: int = member_count_result.scalar_one()

    # is_member
    is_member_stmt = select(ChallengeMember.id).where(
        ChallengeMember.challenge_id == challenge_id,
        ChallengeMember.user_id == user_id,
    )
    is_member_result = await db.execute(is_member_stmt)
    is_member = is_member_result.first() is not None

    return ChallengeDetail(
        id=challenge.id,
        title=challenge.title,
        description=challenge.description,
        category=challenge.category,
        start_date=challenge.start_date,
        end_date=challenge.end_date,
        verification_frequency=challenge.verification_frequency,
        photo_required=challenge.photo_required,
        is_public=challenge.is_public,
        invite_code=challenge.invite_code,
        status=challenge.status,
        creator=UserBrief(
            id=creator.id,
            nickname=creator.nickname,
            profile_image_url=creator.profile_image_url,
        ),
        member_count=member_count,
        is_member=is_member,
        created_at=challenge.created_at,
    )


async def create_challenge(
    db: AsyncSession,
    user_id: uuid.UUID,
    data: ChallengeCreate,
) -> ChallengeCreateResponse:
    # validate date range
    if data.end_date <= data.start_date:
        raise AppException(
            status_code=422,
            code="INVALID_DATE_RANGE",
            message="종료일은 시작일보다 늦어야 합니다.",
        )

    # validate verification_frequency
    freq_type = data.verification_frequency.get("type")
    if freq_type not in ("daily", "weekly"):
        raise AppException(
            status_code=422,
            code="INVALID_FREQUENCY",
            message="verification_frequency.type은 daily 또는 weekly여야 합니다.",
        )
    if freq_type == "weekly":
        times_per_week = data.verification_frequency.get("times_per_week")
        if not isinstance(times_per_week, int) or times_per_week <= 0:
            raise AppException(
                status_code=422,
                code="INVALID_FREQUENCY",
                message="weekly 주파수는 times_per_week 양의 정수가 필요합니다.",
            )

    # generate unique invite_code
    for _ in range(10):
        code = _generate_invite_code()
        existing = await db.execute(
            select(Challenge.id).where(Challenge.invite_code == code)
        )
        if existing.first() is None:
            break
    else:
        raise AppException(
            status_code=500,
            code="INTERNAL_ERROR",
            message="초대 코드 생성에 실패했습니다. 잠시 후 다시 시도해주세요.",
        )

    # get creator info
    creator_result = await db.execute(select(User).where(User.id == user_id))
    creator = creator_result.scalar_one_or_none()
    if creator is None:
        raise AppException(
            status_code=401,
            code="UNAUTHORIZED",
            message="인증 정보를 확인할 수 없습니다.",
        )

    # create Challenge
    challenge = Challenge(
        creator_id=user_id,
        title=data.title,
        description=data.description,
        category=data.category,
        start_date=data.start_date,
        end_date=data.end_date,
        verification_frequency=data.verification_frequency,
        photo_required=data.photo_required,
        invite_code=code,
        is_public=False,
        status="active",
    )
    db.add(challenge)
    await db.flush()  # get challenge.id

    # create ChallengeMember (creator)
    member = ChallengeMember(
        challenge_id=challenge.id,
        user_id=user_id,
    )
    db.add(member)
    await db.commit()
    await db.refresh(challenge)

    return ChallengeCreateResponse(
        id=challenge.id,
        title=challenge.title,
        description=challenge.description,
        category=challenge.category,
        start_date=challenge.start_date,
        end_date=challenge.end_date,
        verification_frequency=challenge.verification_frequency,
        photo_required=challenge.photo_required,
        is_public=challenge.is_public,
        invite_code=challenge.invite_code,
        status=challenge.status,
        creator=UserBrief(
            id=creator.id,
            nickname=creator.nickname,
            profile_image_url=creator.profile_image_url,
        ),
        member_count=1,
        created_at=challenge.created_at,
    )


async def get_by_invite_code(
    db: AsyncSession,
    code: str,
    user_id: uuid.UUID,
) -> ChallengeDetail:
    stmt = select(Challenge).where(Challenge.invite_code == code)
    result = await db.execute(stmt)
    challenge = result.scalar_one_or_none()
    if challenge is None:
        raise AppException(
            status_code=404,
            code="INVALID_INVITE_CODE",
            message="존재하지 않는 초대 코드입니다.",
        )
    return await get_challenge_detail(db=db, challenge_id=challenge.id, user_id=user_id)


async def join_challenge(
    db: AsyncSession,
    challenge_id: uuid.UUID,
    user_id: uuid.UUID,
) -> JoinResponse:
    # Challenge 조회
    result = await db.execute(select(Challenge).where(Challenge.id == challenge_id))
    challenge = result.scalar_one_or_none()
    if challenge is None:
        raise AppException(
            status_code=404,
            code="CHALLENGE_NOT_FOUND",
            message="챌린지를 찾을 수 없습니다.",
        )

    # 종료된 챌린지 확인
    if challenge.status == "completed":
        raise AppException(
            status_code=400,
            code="CHALLENGE_ENDED",
            message="이미 종료된 챌린지입니다.",
        )

    # 이미 멤버인지 확인
    existing_stmt = select(ChallengeMember).where(
        ChallengeMember.challenge_id == challenge_id,
        ChallengeMember.user_id == user_id,
    )
    existing_result = await db.execute(existing_stmt)
    if existing_result.scalar_one_or_none() is not None:
        raise AppException(
            status_code=409,
            code="ALREADY_JOINED",
            message="이미 참여 중인 챌린지입니다.",
        )

    member = ChallengeMember(
        challenge_id=challenge_id,
        user_id=user_id,
    )
    db.add(member)
    await db.commit()
    await db.refresh(member)

    return JoinResponse(
        challenge_id=challenge_id,
        joined_at=member.joined_at,
    )
