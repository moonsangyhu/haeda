import math
import uuid
from datetime import date

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.exceptions import AppException
from app.models.challenge import Challenge
from app.models.challenge_member import ChallengeMember
from app.models.user import User
from app.models.verification import Verification
from app.schemas.challenge import ChallengeDetail, ChallengeListItem
from app.schemas.user import UserBrief


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
