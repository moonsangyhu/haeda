import calendar
import uuid
from datetime import date

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.exceptions import AppException
from app.models.challenge import Challenge
from app.models.challenge_member import ChallengeMember
from app.models.day_completion import DayCompletion
from app.models.user import User
from app.models.verification import Verification
from app.models.character_equip import CharacterEquip
from app.models.item import Item
from app.schemas.challenge import (
    CalendarMember,
    CalendarResponse,
    CharacterSlotBrief,
    DayEntry,
    MemberCharacter,
)


def _determine_season(month: int) -> str:
    """월을 계절 아이콘 타입으로 변환한다."""
    if 3 <= month <= 5:
        return "spring"
    elif 6 <= month <= 8:
        return "summer"
    elif 9 <= month <= 11:
        return "fall"
    else:
        return "winter"


async def get_calendar(
    db: AsyncSession,
    challenge_id: uuid.UUID,
    user_id: uuid.UUID,
    year: int,
    month: int,
) -> CalendarResponse:
    # 1. Challenge 조회
    challenge_stmt = select(Challenge).where(Challenge.id == challenge_id)
    challenge_result = await db.execute(challenge_stmt)
    challenge = challenge_result.scalar_one_or_none()
    if challenge is None:
        raise AppException(
            status_code=404,
            code="CHALLENGE_NOT_FOUND",
            message="챌린지를 찾을 수 없습니다.",
        )

    # 2. 멤버십 확인
    membership_stmt = select(ChallengeMember.id).where(
        ChallengeMember.challenge_id == challenge_id,
        ChallengeMember.user_id == user_id,
    )
    membership_result = await db.execute(membership_stmt)
    if membership_result.first() is None:
        raise AppException(
            status_code=403,
            code="NOT_A_MEMBER",
            message="챌린지 참여자가 아닙니다.",
        )

    # 3. 해당 월 날짜 범위 계산
    last_day = calendar.monthrange(year, month)[1]
    month_start = date(year, month, 1)
    month_end = date(year, month, last_day)

    # 4. 챌린지 멤버 + User 목록
    members_stmt = (
        select(User)
        .join(ChallengeMember, ChallengeMember.user_id == User.id)
        .where(ChallengeMember.challenge_id == challenge_id)
    )
    members_result = await db.execute(members_stmt)
    users = members_result.scalars().all()
    # 캐릭터 착용 정보 로딩
    user_ids = [u.id for u in users]
    equip_stmt = select(CharacterEquip).where(CharacterEquip.user_id.in_(user_ids))
    equip_result = await db.execute(equip_stmt)
    equip_map: dict[uuid.UUID, CharacterEquip] = {
        e.user_id: e for e in equip_result.scalars().all()
    }

    # 착용 아이템 ID 수집 → Item 일괄 조회
    item_ids: set[uuid.UUID] = set()
    for eq in equip_map.values():
        for slot in [eq.hat_item_id, eq.top_item_id, eq.bottom_item_id, eq.shoes_item_id, eq.accessory_item_id]:
            if slot:
                item_ids.add(slot)

    item_map: dict[uuid.UUID, Item] = {}
    if item_ids:
        item_stmt = select(Item).where(Item.id.in_(item_ids))
        item_result = await db.execute(item_stmt)
        item_map = {i.id: i for i in item_result.scalars().all()}

    def _slot(item_id: uuid.UUID | None) -> CharacterSlotBrief | None:
        if item_id and item_id in item_map:
            it = item_map[item_id]
            return CharacterSlotBrief(asset_key=it.asset_key, rarity=it.rarity)
        return None

    members: list[CalendarMember] = []
    for u in users:
        eq = equip_map.get(u.id)
        char = MemberCharacter(
            hat=_slot(eq.hat_item_id) if eq else None,
            top=_slot(eq.top_item_id) if eq else None,
            bottom=_slot(eq.bottom_item_id) if eq else None,
            shoes=_slot(eq.shoes_item_id) if eq else None,
            accessory=_slot(eq.accessory_item_id) if eq else None,
        )
        members.append(
            CalendarMember(
                id=u.id,
                nickname=u.nickname,
                profile_image_url=u.profile_image_url,
                character=char,
            )
        )

    # 5. 해당 월의 Verification 조회 (날짜별 그룹핑)
    verif_stmt = select(Verification.date, Verification.user_id).where(
        Verification.challenge_id == challenge_id,
        Verification.date >= month_start,
        Verification.date <= month_end,
    )
    verif_result = await db.execute(verif_stmt)
    verif_rows = verif_result.all()

    # 날짜 → user_id 목록 매핑
    verified_by_date: dict[date, list[uuid.UUID]] = {}
    for row in verif_rows:
        verified_by_date.setdefault(row.date, []).append(row.user_id)

    # 6. DayCompletion 조회
    dc_stmt = select(DayCompletion).where(
        DayCompletion.challenge_id == challenge_id,
        DayCompletion.date >= month_start,
        DayCompletion.date <= month_end,
    )
    dc_result = await db.execute(dc_stmt)
    day_completions = dc_result.scalars().all()
    dc_map: dict[date, DayCompletion] = {dc.date: dc for dc in day_completions}

    # 7. days[] 조립: 인증이 있거나 DayCompletion이 있는 날만 포함
    all_dates = set(verified_by_date.keys()) | set(dc_map.keys())
    days: list[DayEntry] = []
    for d in sorted(all_dates):
        dc = dc_map.get(d)
        days.append(
            DayEntry(
                date=d,
                verified_members=verified_by_date.get(d, []),
                all_completed=dc is not None,
                season_icon_type=dc.season_icon_type if dc else None,
            )
        )

    return CalendarResponse(
        challenge_id=challenge_id,
        year=year,
        month=month,
        members=members,
        days=days,
    )
