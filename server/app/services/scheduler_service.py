"""Challenge end scheduler — domain-model.md §4 '챌린지 종료' 구현.

스케줄러 (매일 자정):
  1. end_date < today && status == 'active' 인 챌린지 조회
  2. status → 'completed' 변경
  3. 각 멤버별 달성률 계산 → badge 부여
  4. (P1) 참여자에게 완료 푸시 알림 발송 — 미구현
"""

import logging
from datetime import date

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.challenge import Challenge
from app.models.challenge_member import ChallengeMember
from app.models.verification import Verification
from app.services.challenge_service import _compute_achievement_rate

logger = logging.getLogger(__name__)

# Badge 규칙: PRD §9 Open Question #3 미확정.
# api-contract.md 예시값 "completed"를 단일 배지로 사용.
BADGE_COMPLETED = "completed"


async def close_expired_challenges(db: AsyncSession, today: date | None = None) -> int:
    """종료 대상 챌린지를 completed로 전환하고 멤버 badge를 부여한다.

    Args:
        db: async DB session
        today: 기준일 (테스트 주입용, 기본값 date.today())

    Returns:
        처리된 챌린지 수
    """
    if today is None:
        today = date.today()

    # 1. 종료 대상 챌린지 조회
    stmt = select(Challenge).where(
        Challenge.status == "active",
        Challenge.end_date < today,
    )
    result = await db.execute(stmt)
    challenges = list(result.scalars().all())

    if not challenges:
        logger.info("close_expired_challenges: 종료 대상 챌린지 없음 (today=%s)", today)
        return 0

    processed = 0
    for challenge in challenges:
        # 2. status → completed
        challenge.status = "completed"

        # 3. 멤버별 달성률 계산 + badge 부여
        members_stmt = select(ChallengeMember).where(
            ChallengeMember.challenge_id == challenge.id,
        )
        members_result = await db.execute(members_stmt)
        members = list(members_result.scalars().all())

        member_user_ids = [m.user_id for m in members]

        # 멤버별 인증 횟수 일괄 조회
        if member_user_ids:
            verif_count_stmt = (
                select(
                    Verification.user_id,
                    func.count(Verification.id).label("cnt"),
                )
                .where(
                    Verification.challenge_id == challenge.id,
                    Verification.user_id.in_(member_user_ids),
                )
                .group_by(Verification.user_id)
            )
            verif_result = await db.execute(verif_count_stmt)
            verif_map = {row.user_id: row.cnt for row in verif_result}
        else:
            verif_map = {}

        for member in members:
            verified_count = verif_map.get(member.user_id, 0)
            # 달성률 계산 (결과는 badge 부여 판단에 사용 가능하나,
            # 현재는 단일 "completed" 배지만 부여)
            _compute_achievement_rate(
                verified_count,
                challenge.start_date,
                challenge.end_date,
                challenge.verification_frequency,
            )
            member.badge = BADGE_COMPLETED

        processed += 1
        logger.info(
            "close_expired_challenges: challenge=%s completed (%d members)",
            challenge.id,
            len(members),
        )

    await db.commit()
    logger.info("close_expired_challenges: %d 챌린지 처리 완료 (today=%s)", processed, today)
    return processed
