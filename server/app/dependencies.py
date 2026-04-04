import uuid

from fastapi import Depends, Header
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.exceptions import AppException


async def get_current_user_id(
    authorization: str | None = Header(default=None),
) -> uuid.UUID:
    """
    Bearer 토큰에서 user_id를 추출하는 의존성.

    이 슬라이스에서는 테스트용 간이 토큰을 사용한다:
        Authorization: Bearer <user-uuid>
    auth 슬라이스에서 카카오 OAuth + JWT로 교체 예정.
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise AppException(
            status_code=401,
            code="UNAUTHORIZED",
            message="인증 토큰이 없거나 만료되었습니다.",
        )
    token = authorization.removeprefix("Bearer ").strip()
    try:
        return uuid.UUID(token)
    except ValueError:
        raise AppException(
            status_code=401,
            code="UNAUTHORIZED",
            message="유효하지 않은 인증 토큰입니다.",
        )
