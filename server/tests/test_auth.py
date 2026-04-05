"""POST /auth/kakao, PUT /auth/profile 엔드포인트 테스트"""
from unittest.mock import patch

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.exceptions import AppException
from app.models.user import User
from app.services import auth_service


@pytest.mark.asyncio
async def test_kakao_login_new_user(client: AsyncClient, db_session: AsyncSession):
    """신규 유저 카카오 로그인 → is_new=True, access/refresh 토큰 발급"""
    mock_kakao = {
        "id": 9999001,
        "kakao_account": {
            "profile": {
                "nickname": "카카오닉네임",
                "profile_image_url": "https://kakao.com/profile.jpg",
            }
        },
    }
    with patch.object(auth_service, "get_kakao_user_info", return_value=mock_kakao):
        resp = await client.post(
            "/api/v1/auth/kakao",
            json={"kakao_access_token": "test-token"},
        )

    assert resp.status_code == 200
    body = resp.json()
    assert "data" in body
    data = body["data"]
    assert data["access_token"]
    assert data["refresh_token"]
    assert data["user"]["is_new"] is True
    assert data["user"]["nickname"] == "카카오닉네임"
    assert data["user"]["profile_image_url"] == "https://kakao.com/profile.jpg"


@pytest.mark.asyncio
async def test_kakao_login_existing_user(client: AsyncClient, user: User):
    """기존 유저 카카오 로그인 → is_new=False, 동일 user_id 반환"""
    mock_kakao = {
        "id": user.kakao_id,
        "kakao_account": {
            "profile": {
                "nickname": user.nickname,
                "profile_image_url": None,
            }
        },
    }
    with patch.object(auth_service, "get_kakao_user_info", return_value=mock_kakao):
        resp = await client.post(
            "/api/v1/auth/kakao",
            json={"kakao_access_token": "test-token"},
        )

    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["user"]["is_new"] is False
    assert data["user"]["id"] == str(user.id)


@pytest.mark.asyncio
async def test_kakao_login_invalid_token(client: AsyncClient):
    """카카오 API 인증 실패 → 401 UNAUTHORIZED"""
    with patch.object(
        auth_service,
        "get_kakao_user_info",
        side_effect=AppException(401, "UNAUTHORIZED", "카카오 토큰이 유효하지 않습니다."),
    ):
        resp = await client.post(
            "/api/v1/auth/kakao",
            json={"kakao_access_token": "bad-token"},
        )
    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "UNAUTHORIZED"


@pytest.mark.asyncio
async def test_update_profile_success(client: AsyncClient, user: User):
    """프로필 닉네임 변경 성공"""
    resp = await client.put(
        "/api/v1/auth/profile",
        data={"nickname": "새닉네임"},
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["nickname"] == "새닉네임"
    assert data["id"] == str(user.id)


@pytest.mark.asyncio
async def test_update_profile_nickname_too_short(client: AsyncClient, user: User):
    """닉네임 1자 → 400 NICKNAME_TOO_SHORT"""
    resp = await client.put(
        "/api/v1/auth/profile",
        data={"nickname": "A"},
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 400
    assert resp.json()["error"]["code"] == "NICKNAME_TOO_SHORT"


@pytest.mark.asyncio
async def test_update_profile_nickname_too_long(client: AsyncClient, user: User):
    """닉네임 31자 → 400 NICKNAME_TOO_LONG"""
    resp = await client.put(
        "/api/v1/auth/profile",
        data={"nickname": "A" * 31},
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 400
    assert resp.json()["error"]["code"] == "NICKNAME_TOO_LONG"


@pytest.mark.asyncio
async def test_update_profile_nickname_boundary_min(client: AsyncClient, user: User):
    """닉네임 정확히 2자 → 성공"""
    resp = await client.put(
        "/api/v1/auth/profile",
        data={"nickname": "AB"},
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 200
    assert resp.json()["data"]["nickname"] == "AB"


@pytest.mark.asyncio
async def test_update_profile_nickname_boundary_max(client: AsyncClient, user: User):
    """닉네임 정확히 30자 → 성공"""
    resp = await client.put(
        "/api/v1/auth/profile",
        data={"nickname": "A" * 30},
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 200
    assert resp.json()["data"]["nickname"] == "A" * 30


@pytest.mark.asyncio
async def test_update_profile_no_auth(client: AsyncClient):
    """인증 없이 프로필 업데이트 → 401 UNAUTHORIZED"""
    resp = await client.put(
        "/api/v1/auth/profile",
        data={"nickname": "테스트"},
    )
    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "UNAUTHORIZED"
