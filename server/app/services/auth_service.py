import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

import httpx
from jose import jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.exceptions import AppException
from app.models.user import User

KAKAO_USER_INFO_URL = "https://kapi.kakao.com/v2/user/me"
UPLOADS_DIR = Path(__file__).parent.parent.parent / "uploads"


async def get_kakao_user_info(kakao_access_token: str) -> dict:
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            KAKAO_USER_INFO_URL,
            headers={"Authorization": f"Bearer {kakao_access_token}"},
            timeout=10.0,
        )
    if resp.status_code != 200:
        raise AppException(401, "UNAUTHORIZED", "카카오 토큰이 유효하지 않습니다.")
    return resp.json()


async def login_or_register(
    db: AsyncSession,
    kakao_id: int,
    nickname: str,
    profile_image_url: str | None,
) -> tuple[User, bool]:
    result = await db.execute(select(User).where(User.kakao_id == kakao_id))
    user = result.scalar_one_or_none()
    if user is not None:
        return user, False

    user = User(
        id=uuid.uuid4(),
        kakao_id=kakao_id,
        nickname=nickname or f"user_{kakao_id}",
        profile_image_url=profile_image_url,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user, True


def create_access_token(user_id: uuid.UUID) -> str:
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
    )
    payload = {"sub": str(user_id), "type": "access", "exp": expire}
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def create_refresh_token(user_id: uuid.UUID) -> str:
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=settings.REFRESH_TOKEN_EXPIRE_MINUTES
    )
    payload = {"sub": str(user_id), "type": "refresh", "exp": expire}
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


async def update_profile(
    db: AsyncSession,
    user_id: uuid.UUID,
    nickname: str,
    profile_image_bytes: bytes | None,
    profile_image_filename: str | None,
) -> User:
    if len(nickname) < 2:
        raise AppException(400, "NICKNAME_TOO_SHORT", "닉네임은 2자 이상이어야 합니다.")
    if len(nickname) > 30:
        raise AppException(400, "NICKNAME_TOO_LONG", "닉네임은 30자 이하여야 합니다.")

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise AppException(404, "USER_NOT_FOUND", "유저를 찾을 수 없습니다.")

    user.nickname = nickname

    if profile_image_bytes and profile_image_filename:
        ext = Path(profile_image_filename).suffix
        filename = f"{user_id}{ext}"
        UPLOADS_DIR.mkdir(exist_ok=True)
        (UPLOADS_DIR / filename).write_bytes(profile_image_bytes)
        user.profile_image_url = f"/uploads/{filename}"

    await db.commit()
    await db.refresh(user)
    return user
