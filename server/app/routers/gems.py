import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.services import gem_pack_catalog, gem_pack_service, treasure_chest_service

router = APIRouter(prefix="/gems", tags=["gems"])


@router.get("/chest")
async def get_chest(
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    state = await treasure_chest_service.get_state(db, user_id)
    return {"data": state.model_dump(mode="json")}


@router.post("/chest/open")
async def open_chest(
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await treasure_chest_service.open_chest(db, user_id)
    await db.commit()
    return {"data": result.model_dump(mode="json")}


@router.get("/packs")
async def list_packs(
    user_id: uuid.UUID = Depends(get_current_user_id),
):
    packs = gem_pack_catalog.list_packs()
    return {"data": {"packs": [p.model_dump() for p in packs]}}


@router.post("/packs/{pack_id}/purchase")
async def purchase_pack(
    pack_id: str,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await gem_pack_service.purchase(db, user_id, pack_id)
    await db.commit()
    return {"data": result.model_dump()}
