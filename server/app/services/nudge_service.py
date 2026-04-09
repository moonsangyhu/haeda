import uuid
from datetime import date

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.exceptions import AppException
from app.models.challenge import Challenge
from app.models.challenge_member import ChallengeMember
from app.models.notification import Notification
from app.models.nudge import Nudge
from app.models.user import User
from app.models.verification import Verification
from app.schemas.nudge import NudgeSendResponse
from app.schemas.user import UserBrief


async def send_nudge(
    db: AsyncSession,
    challenge_id: uuid.UUID,
    sender_id: uuid.UUID,
    receiver_id: uuid.UUID,
) -> NudgeSendResponse:
    # 1. Validate sender != receiver
    if sender_id == receiver_id:
        raise AppException(
            status_code=400,
            code="CANNOT_NUDGE_SELF",
            message="자기 자신을 콕 찌를 수 없습니다.",
        )

    # 2. Get challenge or 404, check status active
    challenge_result = await db.execute(
        select(Challenge).where(Challenge.id == challenge_id)
    )
    challenge = challenge_result.scalar_one_or_none()
    if challenge is None:
        raise AppException(
            status_code=404,
            code="CHALLENGE_NOT_FOUND",
            message="챌린지를 찾을 수 없습니다.",
        )
    if challenge.status != "active":
        raise AppException(
            status_code=400,
            code="CHALLENGE_ENDED",
            message="종료된 챌린지입니다.",
        )

    # 3. Check sender is member
    sender_member_result = await db.execute(
        select(ChallengeMember).where(
            ChallengeMember.challenge_id == challenge_id,
            ChallengeMember.user_id == sender_id,
        )
    )
    if sender_member_result.scalar_one_or_none() is None:
        raise AppException(
            status_code=403,
            code="NOT_A_MEMBER",
            message="챌린지 참여자가 아닙니다.",
        )

    # 4. Check receiver is member
    receiver_member_result = await db.execute(
        select(ChallengeMember).where(
            ChallengeMember.challenge_id == challenge_id,
            ChallengeMember.user_id == receiver_id,
        )
    )
    if receiver_member_result.scalar_one_or_none() is None:
        raise AppException(
            status_code=403,
            code="NOT_A_MEMBER",
            message="챌린지 참여자가 아닙니다.",
        )

    today = date.today()

    # 5. Check receiver has NOT verified today
    verification_result = await db.execute(
        select(Verification).where(
            Verification.challenge_id == challenge_id,
            Verification.user_id == receiver_id,
            Verification.date == today,
        )
    )
    if verification_result.scalar_one_or_none() is not None:
        raise AppException(
            status_code=400,
            code="ALREADY_VERIFIED",
            message="이미 인증을 완료한 사용자입니다.",
        )

    # 6. Check not already nudged today
    nudge_check_result = await db.execute(
        select(Nudge).where(
            Nudge.sender_id == sender_id,
            Nudge.receiver_id == receiver_id,
            Nudge.challenge_id == challenge_id,
            Nudge.date == today,
        )
    )
    if nudge_check_result.scalar_one_or_none() is not None:
        raise AppException(
            status_code=409,
            code="ALREADY_NUDGED",
            message="오늘 이미 콕 찔렀습니다.",
        )

    # 7. Create Nudge record
    nudge = Nudge(
        challenge_id=challenge_id,
        sender_id=sender_id,
        receiver_id=receiver_id,
        date=today,
    )
    db.add(nudge)

    # 8. Get sender User for nickname
    sender_result = await db.execute(
        select(User).where(User.id == sender_id)
    )
    sender = sender_result.scalar_one()

    # 9. Create Notification record
    notification = Notification(
        user_id=receiver_id,
        type="nudge",
        title=f"{sender.nickname}님이 콕 찔렀어요!",
        body=f"{challenge.title} 인증을 해주세요",
        data_json={"challenge_id": str(challenge_id), "sender_id": str(sender_id)},
    )
    db.add(notification)

    # 10. Commit and refresh
    await db.commit()
    await db.refresh(nudge)

    sender_brief = UserBrief(
        id=sender.id,
        nickname=sender.nickname,
        profile_image_url=sender.profile_image_url,
    )

    return NudgeSendResponse(
        id=nudge.id,
        challenge_id=nudge.challenge_id,
        sender=sender_brief,
        receiver_id=nudge.receiver_id,
        date=nudge.date,
        created_at=nudge.created_at,
    )
