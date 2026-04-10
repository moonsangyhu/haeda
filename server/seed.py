"""
시드 데이터 스크립트 — mvp-slice-01.md §5 기준

사용법:
  cd server
  python seed.py

전제: PostgreSQL DB가 실행 중이고, alembic upgrade head 완료 상태.
"""

import asyncio
import uuid
from datetime import date, datetime, timezone

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import _get_session_factory

# ── 고정 UUID (테스트 토큰으로 사용) ──
USER_1_ID = uuid.UUID("11111111-1111-1111-1111-111111111111")
USER_2_ID = uuid.UUID("22222222-2222-2222-2222-222222222222")
USER_3_ID = uuid.UUID("33333333-3333-3333-3333-333333333333")
CHALLENGE_1_ID = uuid.UUID("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")


def _season(d: date) -> str:
    m = d.month
    if 3 <= m <= 5:
        return "spring"
    elif 6 <= m <= 8:
        return "summer"
    elif 9 <= m <= 11:
        return "fall"
    else:
        return "winter"


async def seed():
    session_factory = _get_session_factory()
    async with session_factory() as db:
        # 기존 데이터 정리 (역순 FK)
        for table in [
            "comments",
            "day_completions",
            "verifications",
            "challenge_members",
            "challenges",
            "users",
        ]:
            await db.execute(text(f"DELETE FROM {table}"))

        # ── Users ──
        await db.execute(
            text(
                "INSERT INTO users (id, kakao_id, nickname, profile_image_url) "
                "VALUES (:id, :kakao_id, :nickname, :profile_image_url)"
            ),
            [
                {"id": str(USER_1_ID), "kakao_id": 1001, "nickname": "김철수", "profile_image_url": None},
                {"id": str(USER_2_ID), "kakao_id": 1002, "nickname": "이영희", "profile_image_url": None},
                {"id": str(USER_3_ID), "kakao_id": 1003, "nickname": "박지민", "profile_image_url": None},
            ],
        )

        # ── Challenge ──
        await db.execute(
            text(
                "INSERT INTO challenges "
                "(id, creator_id, title, description, category, start_date, end_date, "
                "verification_frequency, photo_required, invite_code, status) "
                "VALUES (:id, :creator_id, :title, :description, :category, :start_date, :end_date, "
                ":frequency, :photo_required, :invite_code, :status)"
            ),
            {
                "id": str(CHALLENGE_1_ID),
                "creator_id": str(USER_1_ID),
                "title": "운동 30일",
                "description": "매일 30분 이상 운동하기",
                "category": "운동",
                "start_date": date(2026, 3, 5),
                "end_date": date(2026, 4, 3),
                "frequency": '{"type": "daily"}',
                "photo_required": False,
                "invite_code": "SPORT30A",
                "status": "active",
            },
        )

        # ── ChallengeMember ──
        for uid in [USER_1_ID, USER_2_ID, USER_3_ID]:
            await db.execute(
                text(
                    "INSERT INTO challenge_members (id, challenge_id, user_id) "
                    "VALUES (:id, :challenge_id, :user_id)"
                ),
                {
                    "id": str(uuid.uuid4()),
                    "challenge_id": str(CHALLENGE_1_ID),
                    "user_id": str(uid),
                },
            )

        # ── Verifications (과거 데이터) ──
        # user_1: 3/5 ~ 3/20 (16일)
        # user_2: 3/5 ~ 3/18 (14일)
        # user_3: 3/5 ~ 3/20 (16일)
        user_ranges = [
            (USER_1_ID, date(2026, 3, 5), date(2026, 3, 20)),
            (USER_2_ID, date(2026, 3, 5), date(2026, 3, 18)),
            (USER_3_ID, date(2026, 3, 5), date(2026, 3, 20)),
        ]

        for uid, start, end in user_ranges:
            d = start
            while d <= end:
                await db.execute(
                    text(
                        "INSERT INTO verifications "
                        "(id, challenge_id, user_id, date, diary_text) "
                        "VALUES (:id, :challenge_id, :user_id, :date, :diary_text)"
                    ),
                    {
                        "id": str(uuid.uuid4()),
                        "challenge_id": str(CHALLENGE_1_ID),
                        "user_id": str(uid),
                        "date": d,
                        "diary_text": f"{d.isoformat()} 인증 완료",
                    },
                )
                d = date.fromordinal(d.toordinal() + 1)

        # ── DayCompletion (3명 모두 인증한 날: 3/5 ~ 3/18) ──
        d = date(2026, 3, 5)
        end = date(2026, 3, 18)
        while d <= end:
            await db.execute(
                text(
                    "INSERT INTO day_completions "
                    "(id, challenge_id, date, season_icon_type) "
                    "VALUES (:id, :challenge_id, :date, :season_icon_type)"
                ),
                {
                    "id": str(uuid.uuid4()),
                    "challenge_id": str(CHALLENGE_1_ID),
                    "date": d,
                    "season_icon_type": _season(d),
                },
            )
            d = date.fromordinal(d.toordinal() + 1)

        await db.commit()
        print("Seed data inserted successfully!")
        print(f"  Users: 3 (김철수, 이영희, 박지민)")
        print(f"  Challenge: 운동 30일 (2026-03-05 ~ 2026-04-03)")
        print(f"  Members: 3")
        print(f"  Verifications: 46 (16+14+16)")
        print(f"  DayCompletions: 14 (3/5~3/18)")
        print(f"\nTest tokens (use as Bearer <uuid>):")
        print(f"  김철수: {USER_1_ID}")
        print(f"  이영희: {USER_2_ID}")
        print(f"  박지민: {USER_3_ID}")


if __name__ == "__main__":
    asyncio.run(seed())
