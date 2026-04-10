import uuid
from datetime import datetime

from pydantic import BaseModel


class CoinBalanceResponse(BaseModel):
    balance: int


class CoinTransactionResponse(BaseModel):
    id: uuid.UUID
    amount: int
    reason: str
    reference_id: uuid.UUID | None
    created_at: datetime

    model_config = {"from_attributes": True}


class CoinTransactionListResponse(BaseModel):
    transactions: list[CoinTransactionResponse]
    next_cursor: str | None


class CoinEarned(BaseModel):
    amount: int
    reason: str
