import uuid

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.exceptions import AppException
from app.models.notification import Notification
from app.schemas.notification import NotificationItem, NotificationListResponse


async def get_notifications(
    db: AsyncSession,
    user_id: uuid.UUID,
    limit: int = 20,
    offset: int = 0,
) -> NotificationListResponse:
    # Query notifications for user, ordered by created_at DESC
    result = await db.execute(
        select(Notification)
        .where(Notification.user_id == user_id)
        .order_by(Notification.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    notifications = result.scalars().all()

    # Get unread count
    unread_count = await get_unread_count(db=db, user_id=user_id)

    items = [
        NotificationItem(
            id=n.id,
            type=n.type,
            title=n.title,
            body=n.body,
            data_json=n.data_json,
            is_read=n.is_read,
            created_at=n.created_at,
        )
        for n in notifications
    ]

    return NotificationListResponse(notifications=items, unread_count=unread_count)


async def mark_as_read(
    db: AsyncSession,
    notification_id: uuid.UUID,
    user_id: uuid.UUID,
) -> None:
    result = await db.execute(
        select(Notification).where(Notification.id == notification_id)
    )
    notification = result.scalar_one_or_none()

    if notification is None:
        raise AppException(
            status_code=404,
            code="NOTIFICATION_NOT_FOUND",
            message="알림을 찾을 수 없습니다.",
        )

    if notification.user_id != user_id:
        raise AppException(
            status_code=403,
            code="FORBIDDEN",
            message="접근 권한이 없습니다.",
        )

    notification.is_read = True
    await db.commit()


async def get_unread_count(
    db: AsyncSession,
    user_id: uuid.UUID,
) -> int:
    result = await db.execute(
        select(func.count()).where(
            Notification.user_id == user_id,
            Notification.is_read == False,  # noqa: E712
        )
    )
    return result.scalar_one()
