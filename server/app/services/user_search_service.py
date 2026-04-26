import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.exceptions import AppException
from app.models.user import User
from app.schemas.user_search import UserSearchByIdResponse
from app.services.friend_service import compute_friendship_status


async def search_by_id(
    db: AsyncSession,
    *,
    viewer_id: uuid.UUID,
    nickname: str,
    discriminator: str,
) -> UserSearchByIdResponse:
    stmt = select(User).where(
        User.nickname == nickname,
        User.discriminator == discriminator,
    )
    result = await db.execute(stmt)
    target = result.scalar_one_or_none()
    if target is None:
        raise AppException(
            status_code=404,
            code="USER_NOT_FOUND",
            message="해당 ID 를 가진 사용자를 찾을 수 없어요.",
        )

    status = await compute_friendship_status(
        db, viewer_id=viewer_id, target_id=target.id
    )

    return UserSearchByIdResponse(
        user_id=target.id,
        nickname=target.nickname,
        discriminator=target.discriminator,
        profile_image_url=target.profile_image_url,
        friendship_status=status,
    )
