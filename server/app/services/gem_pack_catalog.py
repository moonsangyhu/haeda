from app.schemas.gem_pack import GemPack

_PACKS: list[GemPack] = [
    GemPack(id="pack_small", gems=1000, bonus_gems=0, price_krw=5000),
    GemPack(id="pack_medium", gems=5000, bonus_gems=500, price_krw=25000),
    GemPack(id="pack_large", gems=12000, bonus_gems=2000, price_krw=60000),
]


def list_packs() -> list[GemPack]:
    return list(_PACKS)


def get_pack(pack_id: str) -> GemPack | None:
    for p in _PACKS:
        if p.id == pack_id:
            return p
    return None
