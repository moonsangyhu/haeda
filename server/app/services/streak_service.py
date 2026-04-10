import uuid
from datetime import date, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.challenge import Challenge
from app.models.challenge_member import ChallengeMember
from app.models.notification import Notification
from app.models.user import User
from app.models.verification import Verification

MILESTONE_THRESHOLDS = {3, 7, 14, 30}


async def calculate_streak(
    db: AsyncSession,
    challenge_id: uuid.UUID,
    user_id: uuid.UUID,
    verification_date: date,
) -> int:
    stmt = (
        select(Verification.date)
        .where(
            Verification.challenge_id == challenge_id,
            Verification.user_id == user_id,
            Verification.date <= verification_date,
        )
        .order_by(Verification.date.desc())
    )
    result = await db.execute(stmt)
    dates = [row[0] for row in result.all()]

    if not dates:
        return 1

    streak = 0
    expected = verification_date
    for d in dates:
        if d == expected:
            streak += 1
            expected = expected - timedelta(days=1)
        else:
            break

    return max(streak, 1)


async def notify_streak_milestone(
    db: AsyncSession,
    challenge_id: uuid.UUID,
    user_id: uuid.UUID,
    streak_count: int,
) -> None:
    if streak_count not in MILESTONE_THRESHOLDS:
        return

    user_stmt = select(User).where(User.id == user_id)
    user_result = await db.execute(user_stmt)
    verifier = user_result.scalar_one_or_none()
    if verifier is None:
        return

    challenge_stmt = select(Challenge).where(Challenge.id == challenge_id)
    challenge_result = await db.execute(challenge_stmt)
    challenge = challenge_result.scalar_one_or_none()
    if challenge is None:
        return

    members_stmt = select(ChallengeMember).where(
        ChallengeMember.challenge_id == challenge_id,
        ChallengeMember.user_id != user_id,
        ChallengeMember.notify_streak.is_(True),
    )
    members_result = await db.execute(members_stmt)
    members = members_result.scalars().all()

    for member in members:
        notification = Notification(
            id=uuid.uuid4(),
            user_id=member.user_id,
            type="streak_milestone",
            title=f"{verifier.nickname}님이 {streak_count}일 연속 인증 달성!",
            body=f"{challenge.title}에서 {streak_count}일 연속 인증을 달성했어요",
            data_json={
                "challenge_id": str(challenge_id),
                "user_id": str(user_id),
                "streak_days": streak_count,
            },
        )
        db.add(notification)
