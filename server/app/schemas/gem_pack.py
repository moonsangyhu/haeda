from pydantic import BaseModel


class GemPack(BaseModel):
    id: str
    gems: int
    bonus_gems: int
    price_krw: int


class GemPacksResponse(BaseModel):
    packs: list[GemPack]


class PurchaseResponse(BaseModel):
    awarded_gems: int
    balance: int
    pack_id: str
