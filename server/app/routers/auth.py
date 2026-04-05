import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, UploadFile
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
                profile_image_url=user.profile_image_url,
                is_new=is_new,
            ),
        )
    )


@router.post("/dev-login", response_model=DataResponse[AuthLoginResponse])
async def dev_login(
    db: AsyncSession = Depends(get_db),
):
    if not settings.DEBUG:
        raise AppException(403, "FORBIDDEN", "Not available in production.")

    DEV_KAKAO_ID = 9999999999
    user, is_new = await auth_service.login_or_register(db, DEV_KAKAO_ID, "dev_user", None)

    access_token = auth_service.create_access_token(user.id)
    refresh_token = auth_service.create_refresh_token(user.id)

    return DataResponse(
        data=AuthLoginResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            user=UserWithIsNew(
                id=user.id,
                nickname=user.nickname,
                profile_image_url=user.profile_image_url,
                is_new=is_new,
            ),
        )
    )


@router.put("/profile", response_model=DataResponse[ProfileUpdateResponse])
async def update_profile(
    nickname: Annotated[str, Form()],
    profile_image: Annotated[UploadFile | None, File()] = None,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    image_bytes = None
    image_filename = None
    if profile_image:
        image_bytes = await profile_image.read()
        image_filename = profile_image.filename

    user = await auth_service.update_profile(db, user_id, nickname, image_bytes, image_filename)

    return DataResponse(
        data=ProfileUpdateResponse(
            id=user.id,
            nickname=user.nickname,
            profile_image_url=user.profile_image_url,
        )
    )
