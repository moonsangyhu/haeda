import time
import uuid
from datetime import datetime

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.exceptions import AppException
from app.models.challenge import Challenge
from app.models.challenge_member import ChallengeMember
from app.models.room_speech import RoomSpeech
from app.models.user import User
from app.schemas.room_speech import RoomSpeechDeleteResult, RoomSpeechItem, RoomSpeechSubmitResult
from app.utils.time import KST, next_cutoff_at

_LAST_POST: dict[tuple[uuid.UUID, uuid.UUID], float] = {}
_RATE_LIMIT_SECONDS = 10


def clear_rate_limit_cache() -> None:
    _LAST_POST.clear()


def _normalize_content(raw: str) -> str:
    content = raw.replace("\r", "").replace("\n", "").strip()
    if not content:
        raise AppException(422, "SPEECH_EMPTY", "내용을 입력해주세요")
    if len(content) > 40:
        raise AppException(422, "SPEECH_TOO_LONG", "한마디는 40자 이내로 입력해주세요")
    return content


async def _assert_member(db: AsyncSession, challenge_id: uuid.UUID, user_id: uuid.UUID) -> None:
    stmt = select(ChallengeMember).where(
        ChallengeMember.challenge_id == challenge_id,
        ChallengeMember.user_id == user_id,
    )
    result = await db.execute(stmt)
    if result.scalar_one_or_none() is None:
        raise AppException(403, "SPEECH_NOT_MEMBER", "이 챌린지의 멤버가 아닙니다")


def _check_rate_limit(challenge_id: uuid.UUID, user_id: uuid.UUID) -> None:
    key = (challenge_id, user_id)
    last = _LAST_POST.get(key)
    if last is not None and (time.monotonic() - last) < _RATE_LIMIT_SECONDS:
        raise AppException(429, "SPEECH_RATE_LIMITED", "너무 빠르게 보내고 있어요. 잠시 후 다시 시도해주세요")
    _LAST_POST[key] = time.monotonic()


async def list_room_speech(
    db: AsyncSession,
    challenge_id: uuid.UUID,
    user_id: uuid.UUID,
) -> list[RoomSpeechItem]:
    await _assert_member(db, challenge_id, user_id)
    now = datetime.now(tz=KST)
    stmt = (
        select(RoomSpeech, User.nickname)
        .join(User, User.id == RoomSpeech.user_id)
        .where(
            RoomSpeech.challenge_id == challenge_id,
            RoomSpeech.expires_at > now,
        )
        .order_by(RoomSpeech.created_at.asc())
    )
    rows = (await db.execute(stmt)).all()
    return [
        RoomSpeechItem(
            user_id=speech.user_id,
            nickname=nickname,
            content=speech.content,
            created_at=speech.created_at,
            expires_at=speech.expires_at,
        )
        for speech, nickname in rows
    ]


async def submit_room_speech(
    db: AsyncSession,
    challenge_id: uuid.UUID,
    user_id: uuid.UUID,
    raw_content: str,
) -> RoomSpeechSubmitResult:
    content = _normalize_content(raw_content)
    await _assert_member(db, challenge_id, user_id)
    _check_rate_limit(challenge_id, user_id)

    stmt = select(Challenge).where(Challenge.id == challenge_id)
    challenge = (await db.execute(stmt)).scalar_one_or_none()
    if challenge is None:
        raise AppException(404, "CHALLENGE_NOT_FOUND", "챌린지를 찾을 수 없습니다")

    expires_at = next_cutoff_at(challenge.day_cutoff_hour)

    existing_stmt = select(RoomSpeech).where(
        RoomSpeech.challenge_id == challenge_id,
        RoomSpeech.user_id == user_id,
    )
    existing = (await db.execute(existing_stmt)).scalar_one_or_none()

    if existing is not None:
        existing.content = content
        existing.created_at = datetime.now(tz=KST)
        existing.expires_at = expires_at
        await db.commit()
        await db.refresh(existing)
        return RoomSpeechSubmitResult(
            content=existing.content,
            created_at=existing.created_at,
            expires_at=existing.expires_at,
        )

    speech = RoomSpeech(
        id=uuid.uuid4(),
        challenge_id=challenge_id,
        user_id=user_id,
        content=content,
        expires_at=expires_at,
    )
    db.add(speech)
    await db.commit()
    await db.refresh(speech)
    return RoomSpeechSubmitResult(
        content=speech.content,
        created_at=speech.created_at,
        expires_at=speech.expires_at,
    )


async def delete_room_speech(
    db: AsyncSession,
    challenge_id: uuid.UUID,
    user_id: uuid.UUID,
) -> RoomSpeechDeleteResult:
    await _assert_member(db, challenge_id, user_id)
    stmt = delete(RoomSpeech).where(
        RoomSpeech.challenge_id == challenge_id,
        RoomSpeech.user_id == user_id,
    )
    await db.execute(stmt)
    await db.commit()
    return RoomSpeechDeleteResult()
