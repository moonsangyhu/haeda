import pytest
from httpx import AsyncClient

from app.models.user import User


@pytest.mark.asyncio
async def test_get_me_includes_discriminator(
    client: AsyncClient, user: User
):
    headers = {"Authorization": f"Bearer {user.id}"}
    resp = await client.get("/api/v1/me", headers=headers)
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["nickname"] == user.nickname
    assert data["discriminator"] == user.discriminator
    assert len(data["discriminator"]) == 5
