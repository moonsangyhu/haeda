import re
import uuid
from datetime import datetime, timezone

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.exceptions import AppException
from app.models.friendship import Friendship
from app.models.user import User
from app.schemas.friendship import (
    ContactMatchItem,
    ContactMatchResponse,
    FriendItem,
    FriendListResponse,
    FriendRequestItem,
    FriendshipResponse,
    PendingRequestsResponse,
)
from app.schemas.user import UserBrief


def _normalize_phone(number: str) -> str:
    return re.sub(r"[\s\-]", "", number)


async def send_friend_request(
    db: AsyncSession,
    requester_id: uuid.UUID,
    addressee_id: uuid.UUID,
) -> FriendshipResponse:
    if requester_id == addressee_id:
        raise AppException(400, "INVALID_REQUEST", "자기 자신에게 친구 요청을 보낼 수 없습니다.")

    stmt = select(Friendship).where(
        or_(
            (Friendship.requester_id == requester_id) & (Friendship.addressee_id == addressee_id),
            (Friendship.requester_id == addressee_id) & (Friendship.addressee_id == requester_id),
        )
    )
    result = await db.execute(stmt)
    existing = result.scalar_one_or_none()
    if existing is not None:
        raise AppException(409, "ALREADY_EXISTS", "이미 친구 요청이 존재하거나 이미 친구입니다.")

    friendship = Friendship(
        id=uuid.uuid4(),
        requester_id=requester_id,
        addressee_id=addressee_id,
        status="pending",
    )
    db.add(friendship)
    await db.flush()
    await db.commit()
    await db.refresh(friendship)
    return FriendshipResponse.model_validate(friendship)


async def get_pending_requests(
    db: AsyncSession,
    user_id: uuid.UUID,
) -> PendingRequestsResponse:
    stmt = (
        select(Friendship, User)
        .join(User, User.id == Friendship.requester_id)
        .where(Friendship.addressee_id == user_id, Friendship.status == "pending")
    )
    result = await db.execute(stmt)
    rows = result.all()

    items = [
        FriendRequestItem(
            id=row.Friendship.id,
            user=UserBrief(
                id=row.User.id,
                nickname=row.User.nickname,
                profile_image_url=row.User.profile_image_url,
            ),
            created_at=row.Friendship.created_at,
        )
        for row in rows
    ]
    return PendingRequestsResponse(requests=items)


async def _get_friendship_for_user(
    db: AsyncSession,
    friendship_id: uuid.UUID,
    user_id: uuid.UUID,
    require_addressee: bool = False,
) -> Friendship:
    stmt = select(Friendship).where(Friendship.id == friendship_id)
    result = await db.execute(stmt)
    friendship = result.scalar_one_or_none()

    if friendship is None:
        raise AppException(404, "FRIENDSHIP_NOT_FOUND", "친구 요청을 찾을 수 없습니다.")

    if require_addressee and friendship.addressee_id != user_id:
        raise AppException(403, "FORBIDDEN", "이 작업에 대한 권한이 없습니다.")

    return friendship


async def accept_friend_request(
    db: AsyncSession,
    friendship_id: uuid.UUID,
    user_id: uuid.UUID,
) -> FriendshipResponse:
    friendship = await _get_friendship_for_user(
        db, friendship_id, user_id, require_addressee=True
    )

    if friendship.status != "pending":
        raise AppException(400, "INVALID_REQUEST", "이미 처리된 친구 요청입니다.")

    friendship.status = "accepted"
    friendship.accepted_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(friendship)
    return FriendshipResponse.model_validate(friendship)


async def reject_friend_request(
    db: AsyncSession,
    friendship_id: uuid.UUID,
    user_id: uuid.UUID,
) -> FriendshipResponse:
    friendship = await _get_friendship_for_user(
        db, friendship_id, user_id, require_addressee=True
    )

    if friendship.status != "pending":
        raise AppException(400, "INVALID_REQUEST", "이미 처리된 친구 요청입니다.")

    friendship.status = "rejected"
    await db.commit()
    await db.refresh(friendship)
    return FriendshipResponse.model_validate(friendship)


async def get_friends(
    db: AsyncSession,
    user_id: uuid.UUID,
) -> FriendListResponse:
    stmt = (
        select(Friendship)
        .where(
            or_(
                Friendship.requester_id == user_id,
                Friendship.addressee_id == user_id,
            ),
            Friendship.status == "accepted",
        )
    )
    result = await db.execute(stmt)
    friendships = result.scalars().all()

    if not friendships:
        return FriendListResponse(friends=[])

    other_user_ids = [
        f.addressee_id if f.requester_id == user_id else f.requester_id
        for f in friendships
    ]

    users_stmt = select(User).where(User.id.in_(other_user_ids))
    users_result = await db.execute(users_stmt)
    users_map = {u.id: u for u in users_result.scalars().all()}

    items = []
    for f in friendships:
        other_id = f.addressee_id if f.requester_id == user_id else f.requester_id
        other = users_map.get(other_id)
        if other:
            items.append(
                FriendItem(
                    user_id=other.id,
                    nickname=other.nickname,
                    profile_image_url=other.profile_image_url,
                )
            )

    return FriendListResponse(friends=items)


async def remove_friend(
    db: AsyncSession,
    friendship_id: uuid.UUID,
    user_id: uuid.UUID,
) -> None:
    stmt = select(Friendship).where(Friendship.id == friendship_id)
    result = await db.execute(stmt)
    friendship = result.scalar_one_or_none()

    if friendship is None:
        raise AppException(404, "FRIENDSHIP_NOT_FOUND", "친구 관계를 찾을 수 없습니다.")

    if friendship.requester_id != user_id and friendship.addressee_id != user_id:
        raise AppException(403, "FORBIDDEN", "이 작업에 대한 권한이 없습니다.")

    await db.delete(friendship)
    await db.commit()


async def match_contacts(
    db: AsyncSession,
    user_id: uuid.UUID,
    phone_numbers: list[str],
) -> ContactMatchResponse:
    normalized = [_normalize_phone(n) for n in phone_numbers]

    users_stmt = select(User).where(
        User.phone_number.in_(normalized),
        User.id != user_id,
    )
    users_result = await db.execute(users_stmt)
    matched_users = users_result.scalars().all()

    if not matched_users:
        return ContactMatchResponse(matches=[])

    matched_ids = [u.id for u in matched_users]

    friendships_stmt = select(Friendship).where(
        or_(
            (Friendship.requester_id == user_id) & (Friendship.addressee_id.in_(matched_ids)),
            (Friendship.addressee_id == user_id) & (Friendship.requester_id.in_(matched_ids)),
        )
    )
    friendships_result = await db.execute(friendships_stmt)
    friendships = friendships_result.scalars().all()

    status_map: dict[uuid.UUID, str] = {}
    for f in friendships:
        other_id = f.addressee_id if f.requester_id == user_id else f.requester_id
        status_map[other_id] = f.status

    matches = [
        ContactMatchItem(
            user_id=u.id,
            nickname=u.nickname,
            profile_image_url=u.profile_image_url,
            friendship_status=status_map.get(u.id),
        )
        for u in matched_users
    ]

    return ContactMatchResponse(matches=matches)
