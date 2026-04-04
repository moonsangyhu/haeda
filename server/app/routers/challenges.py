import os
import uuid
from datetime import date

from fastapi import APIRouter, Depends, File, Form, Query, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user_id
from app.schemas.challenge import ChallengeCreate
from app.services import calendar_service, challenge_service, verification_service

router = APIRouter(prefix="/challenges", tags=["challenges"])

UPLOADS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "uploads")


@router.post("", status_code=201)
async def create_challenge(
    body: ChallengeCreate,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await challenge_service.create_challenge(
        db=db,
        user_id=user_id,
        data=body,
    )
    return {"data": result.model_dump()}


@router.get("/invite/{code}")
async def get_challenge_by_invite_code(
    code: str,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    detail = await challenge_service.get_by_invite_code(
        db=db,
        code=code,
        user_id=user_id,
    )
    return {"data": detail.model_dump()}


@router.get("/{challenge_id}")
async def get_challenge(
    challenge_id: uuid.UUID,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    detail = await challenge_service.get_challenge_detail(
        db=db,
        challenge_id=challenge_id,
        user_id=user_id,
    )
    return {"data": detail.model_dump()}


@router.post("/{challenge_id}/verifications", status_code=201)
async def create_verification(
    challenge_id: uuid.UUID,
    diary_text: str = Form(...),
    photo: UploadFile | None = File(default=None),
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    photo_url: str | None = None
    if photo is not None and photo.filename:
        ext = os.path.splitext(photo.filename)[1].lower()
        filename = f"{uuid.uuid4()}{ext}"
        file_path = os.path.join(UPLOADS_DIR, filename)
        os.makedirs(UPLOADS_DIR, exist_ok=True)
        contents = await photo.read()
        with open(file_path, "wb") as f:
            f.write(contents)
        photo_url = f"/uploads/{filename}"

    result = await verification_service.create_verification(
        db=db,
        challenge_id=challenge_id,
        user_id=user_id,
        diary_text=diary_text,
        photo_url=photo_url,
    )
    return {"data": result.model_dump()}


@router.get("/{challenge_id}/verifications/{verification_date}")
async def get_daily_verifications(
    challenge_id: uuid.UUID,
    verification_date: date,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await verification_service.get_daily_verifications(
        db=db,
        challenge_id=challenge_id,
        user_id=user_id,
        target_date=verification_date,
    )
    return {"data": result.model_dump()}


@router.get("/{challenge_id}/calendar")
async def get_calendar(
    challenge_id: uuid.UUID,
    year: int = Query(..., description="연도"),
    month: int = Query(..., ge=1, le=12, description="월 (1~12)"),
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    cal = await calendar_service.get_calendar(
        db=db,
        challenge_id=challenge_id,
        user_id=user_id,
        year=year,
        month=month,
    )
    return {"data": cal.model_dump()}


@router.get("/{challenge_id}/completion")
async def get_completion(
    challenge_id: uuid.UUID,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await challenge_service.get_completion(
        db=db,
        challenge_id=challenge_id,
        user_id=user_id,
    )
    return {"data": result.model_dump()}


@router.post("/{challenge_id}/join")
async def join_challenge(
    challenge_id: uuid.UUID,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await challenge_service.join_challenge(
        db=db,
        challenge_id=challenge_id,
        user_id=user_id,
    )
    return {"data": result.model_dump()}
