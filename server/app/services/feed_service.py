import uuid
from datetime import datetime

from sqlalchemy import delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.exceptions import AppException
from app.models.challenge import Challenge
from app.models.clap import Clap
from app.models.feed_item import FeedItem
from app.models.friendship import Friendship
from app.models.user import User
from app.models.verification import Verification
from app.schemas.feed import ClapToggleResponse, FeedItemResponse, FeedListResponse
from app.schemas.user import UserBrief


async def create_feed_item(
    db: AsyncSession,
    actor_id: uuid.UUID,
    type: str,
    reference_id: uuid.UUID,
    challenge_id: uuid.UUID,
) -> None:
    feed_item = FeedItem(
        actor_id=actor_id,
        type=type,
        reference_id=reference_id,
        challenge_id=challenge_id,
    )
    db.add(feed_item)
    await db.flush()
    await db.commit()


async def get_friend_feed(
    db: AsyncSession,
    user_id: uuid.UUID,
    cursor: str | None,
    limit: int,
) -> FeedListResponse:
    # get friend user IDs (accepted friendships)
    friendship_stmt = select(Friendship).where(
        or_(
            Friendship.requester_id == user_id,
            Friendship.addressee_id == user_id,
        ),
        Friendship.status == "accepted",
    )
    friendship_result = await db.execute(friendship_stmt)
    friendships = friendship_result.scalars().all()

    friend_ids: list[uuid.UUID] = []
    for f in friendships:
        if f.requester_id == user_id:
            friend_ids.append(f.addressee_id)
        else:
            friend_ids.append(f.requester_id)

    if not friend_ids:
        return FeedListResponse(items=[], next_cursor=None)

    # query feed items
    stmt = (
        select(FeedItem, User, Challenge)
        .join(User, User.id == FeedItem.actor_id)
        .join(Challenge, Challenge.id == FeedItem.challenge_id)
        .where(FeedItem.actor_id.in_(friend_ids))
        .order_by(FeedItem.created_at.desc())
    )

    if cursor is not None:
        cursor_dt = datetime.fromisoformat(cursor)
        stmt = stmt.where(FeedItem.created_at < cursor_dt)

    stmt = stmt.limit(limit + 1)
    result = await db.execute(stmt)
    rows = result.all()

    has_more = len(rows) > limit
    page_rows = rows[:limit]

    # collect feed_item_ids and verification reference_ids
    feed_item_ids = [row.FeedItem.id for row in page_rows]

    # clap counts per feed item
    if feed_item_ids:
        clap_count_stmt = (
            select(Clap.feed_item_id, func.count(Clap.id).label("cnt"))
            .where(Clap.feed_item_id.in_(feed_item_ids))
            .group_by(Clap.feed_item_id)
        )
        clap_count_result = await db.execute(clap_count_stmt)
        clap_count_map: dict[uuid.UUID, int] = {
            row.feed_item_id: row.cnt for row in clap_count_result
        }

        # has_clapped per feed item for current user
        has_clapped_stmt = select(Clap.feed_item_id).where(
            Clap.feed_item_id.in_(feed_item_ids),
            Clap.user_id == user_id,
        )
        has_clapped_result = await db.execute(has_clapped_stmt)
        has_clapped_set: set[uuid.UUID] = {row[0] for row in has_clapped_result.all()}
    else:
        clap_count_map = {}
        has_clapped_set = set()

    # verification data (photo_urls, diary_text) for verification-type items
    verification_type_ids = [
        row.FeedItem.reference_id
        for row in page_rows
        if row.FeedItem.type == "verification"
    ]
    verification_map: dict[uuid.UUID, Verification] = {}
    if verification_type_ids:
        verif_stmt = select(Verification).where(
            Verification.id.in_(verification_type_ids)
        )
        verif_result = await db.execute(verif_stmt)
        for v in verif_result.scalars().all():
            verification_map[v.id] = v

    items: list[FeedItemResponse] = []
    for row in page_rows:
        fi = row.FeedItem
        verif = verification_map.get(fi.reference_id) if fi.type == "verification" else None

        items.append(
            FeedItemResponse(
                id=fi.id,
                actor=UserBrief(
                    id=row.User.id,
                    nickname=row.User.nickname,
                    discriminator=row.User.discriminator,
                    profile_image_url=row.User.profile_image_url,
                ),
                type=fi.type,
                challenge_title=row.Challenge.title,
                challenge_id=fi.challenge_id,
                photo_urls=verif.photo_urls if verif else None,
                diary_text=verif.diary_text if verif else None,
                clap_count=clap_count_map.get(fi.id, 0),
                has_clapped=fi.id in has_clapped_set,
                created_at=fi.created_at,
            )
        )

    next_cursor: str | None = None
    if has_more and page_rows:
        last_item = page_rows[-1].FeedItem
        next_cursor = last_item.created_at.isoformat()

    return FeedListResponse(items=items, next_cursor=next_cursor)


async def toggle_clap(
    db: AsyncSession,
    feed_item_id: uuid.UUID,
    user_id: uuid.UUID,
) -> ClapToggleResponse:
    # check feed item exists
    fi_result = await db.execute(
        select(FeedItem).where(FeedItem.id == feed_item_id)
    )
    feed_item = fi_result.scalar_one_or_none()
    if feed_item is None:
        raise AppException(
            status_code=404,
            code="NOT_FOUND",
            message="피드 아이템을 찾을 수 없습니다.",
        )

    # check existing clap
    existing_stmt = select(Clap).where(
        Clap.feed_item_id == feed_item_id,
        Clap.user_id == user_id,
    )
    existing_result = await db.execute(existing_stmt)
    existing_clap = existing_result.scalar_one_or_none()

    if existing_clap is not None:
        await db.execute(
            delete(Clap).where(
                Clap.feed_item_id == feed_item_id,
                Clap.user_id == user_id,
            )
        )
        clapped = False
    else:
        new_clap = Clap(
            feed_item_id=feed_item_id,
            user_id=user_id,
        )
        db.add(new_clap)
        clapped = True

    await db.commit()

    # count total claps
    count_result = await db.execute(
        select(func.count(Clap.id)).where(Clap.feed_item_id == feed_item_id)
    )
    clap_count: int = count_result.scalar_one()

    return ClapToggleResponse(clapped=clapped, clap_count=clap_count)
