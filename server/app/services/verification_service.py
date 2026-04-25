import uuid
from datetime import date

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.exceptions import AppException
from app.models.challenge import Challenge
from app.models.challenge_member import ChallengeMember
from app.models.day_completion import DayCompletion
from app.models.user import User
from app.models.verification import Verification
from app.schemas.coin import CoinEarned
from app.schemas.user import UserBrief
from app.schemas.verification import (
    DailyVerificationsResponse,
    VerificationCreateResponse,
    VerificationDetailResponse,
    VerificationItem,
)
from app.services import gem_service, streak_service
from app.services.calendar_service import _determine_season
from app.services.character_helpers import load_member_characters
from app.utils.time import effective_today


async def _get_challenge_or_404(db: AsyncSession, challenge_id: uuid.UUID) -> Challenge:
    stmt = select(Challenge).where(Challenge.id == challenge_id)
    result = await db.execute(stmt)
    challenge = result.scalar_one_or_none()
    if challenge is None:
        raise AppException(
            status_code=404,
            code="CHALLENGE_NOT_FOUND",
            message="챌린지를 찾을 수 없습니다.",
        )
    return challenge


async def _check_membership(
    db: AsyncSession, challenge_id: uuid.UUID, user_id: uuid.UUID
) -> None:
    stmt = select(ChallengeMember.id).where(
        ChallengeMember.challenge_id == challenge_id,
        ChallengeMember.user_id == user_id,
    )
    result = await db.execute(stmt)
    if result.first() is None:
        raise AppException(
            status_code=403,
            code="NOT_A_MEMBER",
            message="챌린지 참여자가 아닙니다.",
        )


async def _get_verification_or_404(
    db: AsyncSession, verification_id: uuid.UUID
) -> Verification:
    stmt = select(Verification).where(Verification.id == verification_id)
    result = await db.execute(stmt)
    verification = result.scalar_one_or_none()
    if verification is None:
        raise AppException(
            status_code=404,
            code="VERIFICATION_NOT_FOUND",
            message="인증을 찾을 수 없습니다.",
        )
    return verification


async def _check_verification_membership(
    db: AsyncSession, verification: Verification, user_id: uuid.UUID
) -> None:
    stmt = select(ChallengeMember.id).where(
        ChallengeMember.challenge_id == verification.challenge_id,
        ChallengeMember.user_id == user_id,
    )
    result = await db.execute(stmt)
    if result.first() is None:
        raise AppException(
            status_code=403,
            code="NOT_A_MEMBER",
            message="챌린지 참여자가 아닙니다.",
        )


async def create_verification(
    db: AsyncSession,
    challenge_id: uuid.UUID,
    user_id: uuid.UUID,
    diary_text: str,
    photo_urls: list[str] | None,
    target_date: date | None = None,
) -> VerificationCreateResponse:
    # 1. Challenge 조회
    challenge = await _get_challenge_or_404(db, challenge_id)

    # 2. 멤버십 확인
    await _check_membership(db, challenge_id, user_id)

    # 3. 챌린지의 day_cutoff_hour 로 effective today 계산
    today = effective_today(challenge.day_cutoff_hour)
    verification_date = target_date if target_date is not None else today

    if challenge.status == "completed":
        raise AppException(
            status_code=400,
            code="CHALLENGE_ENDED",
            message="이미 종료된 챌린지입니다.",
        )

    # 4. 미래 날짜 불가
    if verification_date > today:
        raise AppException(
            status_code=400,
            code="INVALID_DATE",
            message="미래 날짜에는 인증할 수 없습니다.",
        )

    # 5. 날짜 범위 확인 (verification_date BETWEEN start_date AND end_date)
    if not (challenge.start_date <= verification_date <= challenge.end_date):
        raise AppException(
            status_code=400,
            code="INVALID_DATE",
            message="인증 가능한 기간이 아닙니다.",
        )

    # 6. 중복 인증 확인
    dup_stmt = select(Verification.id).where(
        Verification.challenge_id == challenge_id,
        Verification.user_id == user_id,
        Verification.date == verification_date,
    )
    dup_result = await db.execute(dup_stmt)
    if dup_result.first() is not None:
        raise AppException(
            status_code=409,
            code="ALREADY_VERIFIED",
            message="해당 날짜에 이미 인증했습니다.",
        )

    # 6. 사진 필수 검증
    if challenge.photo_required and not photo_urls:
        raise AppException(
            status_code=400,
            code="PHOTO_REQUIRED",
            message="이 챌린지는 사진 첨부가 필수입니다.",
        )

    # 7. Verification 레코드 생성
    verification = Verification(
        id=uuid.uuid4(),
        challenge_id=challenge_id,
        user_id=user_id,
        date=verification_date,
        photo_urls=photo_urls,
        diary_text=diary_text,
    )
    db.add(verification)
    await db.flush()  # id 확보를 위해 flush (commit 전)

    coins_earned: list[CoinEarned] = []

    # streak 계산 및 마일스톤 알림
    streak_count = await streak_service.calculate_streak(
        db=db,
        challenge_id=challenge_id,
        user_id=user_id,
        verification_date=verification_date,
    )
    await streak_service.notify_streak_milestone(
        db=db,
        challenge_id=challenge_id,
        user_id=user_id,
        streak_count=streak_count,
    )

    # gem 지급 (인증 완료 시 10 coins)
    await gem_service.award_gems(
        db=db,
        user_id=user_id,
        amount=10,
        reason="VERIFICATION",
        reference_id=challenge_id,
    )
    coins_earned.append(CoinEarned(amount=10, reason="VERIFICATION"))

    # streak 보너스
    if streak_count == 3:
        await gem_service.award_gems(
            db=db,
            user_id=user_id,
            amount=15,
            reason="STREAK_3",
            reference_id=challenge_id,
        )
        coins_earned.append(CoinEarned(amount=15, reason="STREAK_3"))
    elif streak_count == 7:
        await gem_service.award_gems(
            db=db,
            user_id=user_id,
            amount=50,
            reason="STREAK_7",
            reference_id=challenge_id,
        )
        coins_earned.append(CoinEarned(amount=50, reason="STREAK_7"))

    # 8. 전원 인증 판정
    # 해당 날짜 인증 수 카운트 (방금 flush된 레코드 포함)
    verif_count_stmt = select(func.count()).where(
        Verification.challenge_id == challenge_id,
        Verification.date == verification_date,
    )
    verif_count_result = await db.execute(verif_count_stmt)
    verif_count = verif_count_result.scalar_one()

    # 챌린지 멤버 수 카운트
    member_count_stmt = select(func.count()).where(
        ChallengeMember.challenge_id == challenge_id,
    )
    member_count_result = await db.execute(member_count_stmt)
    member_count = member_count_result.scalar_one()

    day_completed = False
    season_icon_type = None

    if verif_count == member_count and member_count > 0:
        # DayCompletion 생성
        season_icon_type = _determine_season(verification_date.month)
        day_completion = DayCompletion(
            id=uuid.uuid4(),
            challenge_id=challenge_id,
            date=verification_date,
            season_icon_type=season_icon_type,
        )
        db.add(day_completion)
        day_completed = True

        # 전원 인증 완료 시 모든 멤버에게 20 coins 지급
        members_stmt = select(ChallengeMember).where(
            ChallengeMember.challenge_id == challenge_id
        )
        members_result = await db.execute(members_stmt)
        members = members_result.scalars().all()
        for member in members:
            await gem_service.award_gems(
                db=db,
                user_id=member.user_id,
                amount=20,
                reason="ALL_COMPLETED",
                reference_id=challenge_id,
            )
        coins_earned.append(CoinEarned(amount=20, reason="ALL_COMPLETED"))

    await db.commit()
    await db.refresh(verification)

    from app.services import feed_service
    await feed_service.create_feed_item(db, user_id, "verification", verification.id, challenge_id)

    return VerificationCreateResponse(
        id=verification.id,
        date=verification.date,
        photo_urls=verification.photo_urls,
        diary_text=verification.diary_text,
        created_at=verification.created_at,
        day_completed=day_completed,
        season_icon_type=season_icon_type,
        coins_earned=coins_earned if coins_earned else None,
    )


async def get_daily_verifications(
    db: AsyncSession,
    challenge_id: uuid.UUID,
    user_id: uuid.UUID,
    target_date: date,
) -> DailyVerificationsResponse:
    # 1. Challenge 조회
    await _get_challenge_or_404(db, challenge_id)

    # 2. 멤버십 확인
    await _check_membership(db, challenge_id, user_id)

    # 3. 해당 날짜의 Verification 목록 조회 (User JOIN)
    verif_stmt = (
        select(Verification, User)
        .join(User, User.id == Verification.user_id)
        .where(
            Verification.challenge_id == challenge_id,
            Verification.date == target_date,
        )
        .order_by(Verification.created_at)
    )
    verif_result = await db.execute(verif_stmt)
    verif_rows = verif_result.all()

    # 캐릭터 정보 로딩
    user_ids = [row.User.id for row in verif_rows]
    char_map = await load_member_characters(db, user_ids)

    # 4. DayCompletion 조회
    dc_stmt = select(DayCompletion).where(
        DayCompletion.challenge_id == challenge_id,
        DayCompletion.date == target_date,
    )
    dc_result = await db.execute(dc_stmt)
    day_completion = dc_result.scalar_one_or_none()

    # 5. VerificationItem 목록 조립
    verifications = [
        VerificationItem(
            id=row.Verification.id,
            user=UserBrief(
                id=row.User.id,
                nickname=row.User.nickname,
                profile_image_url=row.User.profile_image_url,
                character=char_map.get(row.User.id),
            ),
            photo_urls=row.Verification.photo_urls,
            diary_text=row.Verification.diary_text,
            created_at=row.Verification.created_at,
        )
        for row in verif_rows
    ]

    return DailyVerificationsResponse(
        date=target_date,
        all_completed=day_completion is not None,
        season_icon_type=day_completion.season_icon_type if day_completion else None,
        verifications=verifications,
    )


async def get_verification_detail(
    db: AsyncSession,
    verification_id: uuid.UUID,
    user_id: uuid.UUID,
) -> VerificationDetailResponse:
    # 1. Verification 조회
    verification = await _get_verification_or_404(db, verification_id)

    # 2. 멤버십 확인
    await _check_verification_membership(db, verification, user_id)

    # 3. Verification 작성자 조회
    user_stmt = select(User).where(User.id == verification.user_id)
    user_result = await db.execute(user_stmt)
    verification_user = user_result.scalar_one()

    char_map = await load_member_characters(db, [verification_user.id])

    return VerificationDetailResponse(
        id=verification.id,
        challenge_id=verification.challenge_id,
        user=UserBrief(
            id=verification_user.id,
            nickname=verification_user.nickname,
            profile_image_url=verification_user.profile_image_url,
            character=char_map.get(verification_user.id),
        ),
        date=verification.date,
        photo_urls=verification.photo_urls,
        diary_text=verification.diary_text,
        created_at=verification.created_at,
    )
