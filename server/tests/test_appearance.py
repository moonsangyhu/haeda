"""PUT /me/character/appearance endpoint tests"""
import pytest
from httpx import AsyncClient

from app.models.user import User


@pytest.mark.asyncio
async def test_update_appearance_success(client: AsyncClient, user: User):
    resp = await client.put(
        "/api/v1/me/character/appearance",
        headers={"Authorization": f"Bearer {user.id}"},
        json={"skin_tone": "dark", "eye_style": "sharp", "hair_style": "long"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert "data" in body
    data = body["data"]
    assert data["skin_tone"] == "dark"
    assert data["eye_style"] == "sharp"
    assert data["hair_style"] == "long"


@pytest.mark.asyncio
async def test_update_appearance_defaults_returned_on_get(client: AsyncClient, user: User):
    # GET character before any update returns defaults
    resp = await client.get(
        "/api/v1/me/character",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["skin_tone"] == "fair"
    assert data["eye_style"] == "round"
    assert data["hair_style"] == "short"


@pytest.mark.asyncio
async def test_update_appearance_persists(client: AsyncClient, user: User):
    # PUT to set appearance
    await client.put(
        "/api/v1/me/character/appearance",
        headers={"Authorization": f"Bearer {user.id}"},
        json={"skin_tone": "light", "eye_style": "sleepy", "hair_style": "curly"},
    )
    # GET should reflect updated values
    resp = await client.get(
        "/api/v1/me/character",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["skin_tone"] == "light"
    assert data["eye_style"] == "sleepy"
    assert data["hair_style"] == "curly"


@pytest.mark.asyncio
async def test_update_appearance_invalid_skin_tone(client: AsyncClient, user: User):
    resp = await client.put(
        "/api/v1/me/character/appearance",
        headers={"Authorization": f"Bearer {user.id}"},
        json={"skin_tone": "blue", "eye_style": "round", "hair_style": "short"},
    )
    assert resp.status_code == 422
    body = resp.json()
    assert body["error"]["code"] == "VALIDATION_ERROR"


@pytest.mark.asyncio
async def test_update_appearance_invalid_eye_style(client: AsyncClient, user: User):
    resp = await client.put(
        "/api/v1/me/character/appearance",
        headers={"Authorization": f"Bearer {user.id}"},
        json={"skin_tone": "fair", "eye_style": "alien", "hair_style": "short"},
    )
    assert resp.status_code == 422
    body = resp.json()
    assert body["error"]["code"] == "VALIDATION_ERROR"


@pytest.mark.asyncio
async def test_update_appearance_invalid_hair_style(client: AsyncClient, user: User):
    resp = await client.put(
        "/api/v1/me/character/appearance",
        headers={"Authorization": f"Bearer {user.id}"},
        json={"skin_tone": "fair", "eye_style": "round", "hair_style": "mohawk"},
    )
    assert resp.status_code == 422
    body = resp.json()
    assert body["error"]["code"] == "VALIDATION_ERROR"


@pytest.mark.asyncio
async def test_update_appearance_no_token(client: AsyncClient):
    resp = await client.put(
        "/api/v1/me/character/appearance",
        json={"skin_tone": "fair", "eye_style": "round", "hair_style": "short"},
    )
    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "UNAUTHORIZED"


@pytest.mark.asyncio
async def test_update_appearance_upsert(client: AsyncClient, user: User):
    # First update
    await client.put(
        "/api/v1/me/character/appearance",
        headers={"Authorization": f"Bearer {user.id}"},
        json={"skin_tone": "dark", "eye_style": "sharp", "hair_style": "long"},
    )
    # Second update overwrites
    resp = await client.put(
        "/api/v1/me/character/appearance",
        headers={"Authorization": f"Bearer {user.id}"},
        json={"skin_tone": "fair", "eye_style": "round", "hair_style": "short"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["skin_tone"] == "fair"
    assert data["eye_style"] == "round"
    assert data["hair_style"] == "short"
