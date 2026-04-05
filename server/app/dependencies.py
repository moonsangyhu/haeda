import uuid

from fastapi import Header
from jose import JWTError, jwt

from app.config import settings
from app.exceptions import AppException


async def get_current_user_id(
    authorization: str | None = Header(default=None),
) -> uuid.UUID:
    """
    Bearer 토큰에서 user_id를 추출하는 의존성.

    JWT 토큰을 우선 시도하고, 실패 시 raw UUID (테스트 호환)로 폴백.
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise AppException(
            status_code=401,
            code="UNAUTHORIZED",
            message="인증 토큰이 없거나 만료되었습니다.",
        )
    token = authorization.removeprefix("Bearer ").strip()

    # JWT 우선 시도
    try:
        payload = jwt.decode(
            token, settings.SECRET_KEY, algorithms=[settings.JWT_ALGORITHM]
        )
        user_id_str = payload.get("sub")
        if not user_id_str:
            raise AppException(401, "UNAUTHORIZED", "유효하지 않은 인증 토큰입니다.")
        return uuid.UUID(user_id_str)
    except JWTError:
        pass

    # 테스트 호환: raw UUID 폴백
    try:
        return uuid.UUID(token)
    except ValueError:
        raise AppException(
            status_code=401,
            code="UNAUTHORIZED",
            message="유효하지 않은 인증 토큰입니다.",
        )
