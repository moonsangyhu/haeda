from pydantic import BaseModel


class CharacterSlotBrief(BaseModel):
    asset_key: str
    rarity: str


class MemberCharacter(BaseModel):
    hat: CharacterSlotBrief | None
    top: CharacterSlotBrief | None
    bottom: CharacterSlotBrief | None
    shoes: CharacterSlotBrief | None
    accessory: CharacterSlotBrief | None
