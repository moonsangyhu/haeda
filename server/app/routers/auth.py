import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, UploadFile
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.dependencies import get_current_user_id
from app.exceptions import AppException
from app.schemas.common import DataResponse
from app.schemas.user import AuthLoginResponse, KakaoLoginRequest, ProfileUpdateResponse, UserWithIsNew
from app.services import auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/kakao", response_model=DataResponse[AuthLoginResponse])
async def kakao_login(
    body: KakaoLoginRequest,
    db: AsyncSession = Depends(get_db),
):
    kakao_info = await auth_service.get_kakao_user_info(body.kakao_access_token)

    kakao_id = kakao_info.get("id")
    if not kakao_id:
        raise AppException(401, "UNAUTHORIZED", "카카오 사용자 정보를 가져올 수 없습니다.")

    profile = kakao_info.get("kakao_account", {}).get("profile", {})
    nickname = profile.get("nickname", f"user_{kakao_id}")
    profile_image_url = profile.get("profile_image_url")

    user, is_new = await auth_service.login_or_register(db, kakao_id, nickname, profile_image_url)

    access_token = auth_service.create_access_token(user.id)
    refresh_token = auth_service.create_refresh_token(user.id)

    return DataResponse(
        data=AuthLoginResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            user=UserWithIsNew(
                id=user.id,
                nickname=user.nickname,
                discriminator=user.discriminator,
                profile_image_url=user.profile_image_url,
                background_color=user.background_color,
                is_new=is_new,
            ),
        )
    )


class DevLoginRequest(BaseModel):
    user_index: int = 1


_DEV_USERS = {
    1: (1001, "김철수"),
    2: (1002, "이영희"),
    3: (1003, "박지민"),
}


@router.post("/dev-login", response_model=DataResponse[AuthLoginResponse])
async def dev_login(
    body: DevLoginRequest = DevLoginRequest(),
    db: AsyncSession = Depends(get_db),
):
    if not settings.DEBUG:
        raise AppException(403, "FORBIDDEN", "Not available in production.")

    kakao_id, nickname = _DEV_USERS.get(body.user_index, (9999999999, "dev_user"))
    user, is_new = await auth_service.login_or_register(db, kakao_id, nickname, None)

    access_token = auth_service.create_access_token(user.id)
    refresh_token = auth_service.create_refresh_token(user.id)

    return DataResponse(
        data=AuthLoginResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            user=UserWithIsNew(
                id=user.id,
                nickname=user.nickname,
                discriminator=user.discriminator,
                profile_image_url=user.profile_image_url,
                background_color=user.background_color,
                is_new=is_new,
            ),
        )
    )


@router.put("/profile", response_model=DataResponse[ProfileUpdateResponse])
async def update_profile(
    nickname: Annotated[str | None, Form()] = None,
    profile_image: Annotated[UploadFile | None, File()] = None,
    background_color: Annotated[str | None, Form()] = None,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    image_bytes = None
    image_filename = None
    if profile_image:
        image_bytes = await profile_image.read()
        image_filename = profile_image.filename

    user = await auth_service.update_profile(
        db,
        user_id,
        nickname,
        image_bytes,
        image_filename,
        background_color,
    )

    return DataResponse(
        data=ProfileUpdateResponse(
            id=user.id,
            nickname=user.nickname,
            discriminator=user.discriminator,
            profile_image_url=user.profile_image_url,
            background_color=user.background_color,
        )
    )
