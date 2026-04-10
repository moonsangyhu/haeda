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
            "character_equips",
            "user_items",
            "items",
            "gem_transactions",
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

        # ── Items (30개: 카테고리당 6개) ──
        items_data = [
            # HAT
            ("HAT", "캡모자", 30, "COMMON", "hat/cap.png"),
            ("HAT", "비니", 40, "COMMON", "hat/beanie.png"),
            ("HAT", "머리띠", 50, "COMMON", "hat/headband.png"),
            ("HAT", "페도라", 120, "RARE", "hat/fedora.png"),
            ("HAT", "베레모", 150, "RARE", "hat/beret.png"),
            ("HAT", "왕관", 400, "EPIC", "hat/crown.png"),
            # TOP
            ("TOP", "흰티", 30, "COMMON", "top/white_tee.png"),
            ("TOP", "줄무늬티", 40, "COMMON", "top/striped_tee.png"),
            ("TOP", "민소매", 50, "COMMON", "top/sleeveless.png"),
            ("TOP", "후드티", 120, "RARE", "top/hoodie.png"),
            ("TOP", "가디건", 150, "RARE", "top/cardigan.png"),
            ("TOP", "턱시도", 400, "EPIC", "top/tuxedo.png"),
            # BOTTOM
            ("BOTTOM", "청바지", 30, "COMMON", "bottom/jeans.png"),
            ("BOTTOM", "반바지", 40, "COMMON", "bottom/shorts.png"),
            ("BOTTOM", "면바지", 50, "COMMON", "bottom/chinos.png"),
            ("BOTTOM", "치마", 120, "RARE", "bottom/skirt.png"),
            ("BOTTOM", "카고바지", 150, "RARE", "bottom/cargo.png"),
            ("BOTTOM", "황금바지", 400, "EPIC", "bottom/golden_pants.png"),
            # SHOES
            ("SHOES", "슬리퍼", 30, "COMMON", "shoes/slippers.png"),
            ("SHOES", "운동화", 40, "COMMON", "shoes/sneakers.png"),
            ("SHOES", "샌들", 50, "COMMON", "shoes/sandals.png"),
            ("SHOES", "부츠", 120, "RARE", "shoes/boots.png"),
            ("SHOES", "하이탑", 150, "RARE", "shoes/hightops.png"),
            ("SHOES", "날개신발", 400, "EPIC", "shoes/winged_shoes.png"),
            # ACCESSORY
            ("ACCESSORY", "시계", 30, "COMMON", "accessory/watch.png"),
            ("ACCESSORY", "가방", 40, "COMMON", "accessory/bag.png"),
            ("ACCESSORY", "스카프", 50, "COMMON", "accessory/scarf.png"),
            ("ACCESSORY", "선글라스", 120, "RARE", "accessory/sunglasses.png"),
            ("ACCESSORY", "이어폰", 150, "RARE", "accessory/earphones.png"),
            ("ACCESSORY", "천사날개", 400, "EPIC", "accessory/angel_wings.png"),
        ]

        for category, name, price, rarity, asset_key in items_data:
            await db.execute(
                text(
                    "INSERT INTO items (id, name, category, price, rarity, asset_key, is_active, sort_order) "
                    "VALUES (:id, :name, :category, :price, :rarity, :asset_key, true, :sort_order)"
                ),
                {
                    "id": str(uuid.uuid4()),
                    "name": name,
                    "category": category,
                    "price": price,
                    "rarity": rarity,
                    "asset_key": asset_key,
                    "sort_order": price,
                },
            )

        # ── GemTransactions (김철수에게 초기 코인 200 지급) ──
        await db.execute(
            text(
                "INSERT INTO gem_transactions (id, user_id, amount, reason) "
                "VALUES (:id, :user_id, :amount, :reason)"
            ),
            {
                "id": str(uuid.uuid4()),
                "user_id": str(USER_1_ID),
                "amount": 200,
                "reason": "DAILY_LOGIN",
            },
        )

        await db.commit()
        print("Seed data inserted successfully!")
        print(f"  Users: 3 (김철수, 이영희, 박지민)")
        print(f"  Challenge: 운동 30일 (2026-03-05 ~ 2026-04-03)")
        print(f"  Members: 3")
        print(f"  Verifications: 46 (16+14+16)")
        print(f"  DayCompletions: 14 (3/5~3/18)")
        print(f"  Items: 30 (6 per category)")
        print(f"  GemTransactions: 1 (김철수 200 coins)")
        print(f"\nTest tokens (use as Bearer <uuid>):")
        print(f"  김철수: {USER_1_ID}")
        print(f"  이영희: {USER_2_ID}")
        print(f"  박지민: {USER_3_ID}")


if __name__ == "__main__":
    asyncio.run(seed())
