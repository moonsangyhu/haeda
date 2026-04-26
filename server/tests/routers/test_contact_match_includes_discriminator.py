import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User


@pytest.mark.asyncio
async def test_contact_match_includes_discriminator(
    client: AsyncClient, db_session: AsyncSession, user: User
):
    target = User(
        kakao_id=77777,
        nickname="매치대상",
        discriminator="33333",
        phone_number="+821012345678",
    )
    db_session.add(target)
    await db_session.commit()

    headers = {"Authorization": f"Bearer {user.id}"}
    resp = await client.post(
        "/api/v1/friends/contact-match",
        headers=headers,
        json={"phone_numbers": ["+821012345678"]},
    )
    assert resp.status_code == 200
    matches = resp.json()["data"]["matches"]
    assert len(matches) == 1
    assert matches[0]["nickname"] == "매치대상"
    assert matches[0]["discriminator"] == "33333"
