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

# ── 고정 아이템 UUID (user_items / character_equips 참조용) ──
ITEM_CAP = uuid.UUID("10000000-0000-0000-0000-000000000001")      # 캡모자
ITEM_BEANIE = uuid.UUID("10000000-0000-0000-0000-000000000002")   # 비니
ITEM_HEADBAND = uuid.UUID("10000000-0000-0000-0000-000000000003") # 머리띠
ITEM_WHITE_TEE = uuid.UUID("10000000-0000-0000-0000-000000000011") # 흰티
ITEM_HOODIE = uuid.UUID("10000000-0000-0000-0000-000000000014")   # 후드티
ITEM_JEANS = uuid.UUID("10000000-0000-0000-0000-000000000021")    # 청바지
ITEM_SNEAKERS = uuid.UUID("10000000-0000-0000-0000-000000000032") # 운동화
ITEM_BOOTS = uuid.UUID("10000000-0000-0000-0000-000000000034")    # 부츠


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
            "claps",
            "feed_items",
            "friendships",
            "character_equips",
            "user_items",
            "items",
            "gem_transactions",
            "notifications",
            "nudges",
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
        # (category, name, price, rarity, asset_key, effect_type, effect_value)
        items_data = [
            # HAT
            (ITEM_CAP,      "HAT", "캡모자",  30,  "COMMON", "hat/cap.png",    None,            None),
            (ITEM_BEANIE,   "HAT", "비니",    40,  "COMMON", "hat/beanie.png", None,            None),
            (ITEM_HEADBAND, "HAT", "머리띠",  50,  "COMMON", "hat/headband.png", None,          None),
            (uuid.UUID("10000000-0000-0000-0000-000000000004"), "HAT", "페도라",  120, "RARE",   "hat/fedora.png",   "COIN_BOOST",    10),
            (uuid.UUID("10000000-0000-0000-0000-000000000005"), "HAT", "베레모",  150, "RARE",   "hat/beret.png",    "STREAK_SHIELD", 1),
            (uuid.UUID("10000000-0000-0000-0000-000000000006"), "HAT", "왕관",    400, "EPIC",   "hat/crown.png",    "STREAK_SHIELD", 3),
            # TOP
            (ITEM_WHITE_TEE, "TOP", "흰티",    30,  "COMMON", "top/white_tee.png",  None,            None),
            (uuid.UUID("10000000-0000-0000-0000-000000000012"), "TOP", "줄무늬티", 40,  "COMMON", "top/striped_tee.png", None,          None),
            (uuid.UUID("10000000-0000-0000-0000-000000000013"), "TOP", "민소매",   50,  "COMMON", "top/sleeveless.png",  None,          None),
            (ITEM_HOODIE,    "TOP", "후드티",  120, "RARE",   "top/hoodie.png",      "VERIFY_BONUS",  3),
            (uuid.UUID("10000000-0000-0000-0000-000000000015"), "TOP", "가디건",   150, "RARE",   "top/cardigan.png",    "COIN_BOOST",   15),
            (uuid.UUID("10000000-0000-0000-0000-000000000016"), "TOP", "턱시도",   400, "EPIC",   "top/tuxedo.png",      "COIN_BOOST",   30),
            # BOTTOM
            (ITEM_JEANS, "BOTTOM", "청바지",   30,  "COMMON", "bottom/jeans.png",        None,            None),
            (uuid.UUID("10000000-0000-0000-0000-000000000022"), "BOTTOM", "반바지",   40,  "COMMON", "bottom/shorts.png",       None,            None),
            (uuid.UUID("10000000-0000-0000-0000-000000000023"), "BOTTOM", "면바지",   50,  "COMMON", "bottom/chinos.png",       None,            None),
            (uuid.UUID("10000000-0000-0000-0000-000000000024"), "BOTTOM", "치마",     120, "RARE",   "bottom/skirt.png",        "VERIFY_BONUS",  3),
            (uuid.UUID("10000000-0000-0000-0000-000000000025"), "BOTTOM", "카고바지", 150, "RARE",   "bottom/cargo.png",        "STREAK_SHIELD", 1),
            (uuid.UUID("10000000-0000-0000-0000-000000000026"), "BOTTOM", "황금바지", 400, "EPIC",   "bottom/golden_pants.png", "VERIFY_BONUS",  10),
            # SHOES
            (uuid.UUID("10000000-0000-0000-0000-000000000031"), "SHOES", "슬리퍼",   30,  "COMMON", "shoes/slippers.png",   None,            None),
            (ITEM_SNEAKERS,                                      "SHOES", "운동화",   40,  "COMMON", "shoes/sneakers.png",   None,            None),
            (uuid.UUID("10000000-0000-0000-0000-000000000033"), "SHOES", "샌들",     50,  "COMMON", "shoes/sandals.png",    None,            None),
            (ITEM_BOOTS,                                         "SHOES", "부츠",     120, "RARE",   "shoes/boots.png",      "STREAK_SHIELD", 1),
            (uuid.UUID("10000000-0000-0000-0000-000000000035"), "SHOES", "하이탑",   150, "RARE",   "shoes/hightops.png",   "COIN_BOOST",    10),
            (uuid.UUID("10000000-0000-0000-0000-000000000036"), "SHOES", "날개신발", 400, "EPIC",   "shoes/winged_shoes.png", "STREAK_SHIELD", 3),
            # ACCESSORY
            (uuid.UUID("10000000-0000-0000-0000-000000000041"), "ACCESSORY", "시계",     30,  "COMMON", "accessory/watch.png",       None,           None),
            (uuid.UUID("10000000-0000-0000-0000-000000000042"), "ACCESSORY", "가방",     40,  "COMMON", "accessory/bag.png",         None,           None),
            (uuid.UUID("10000000-0000-0000-0000-000000000043"), "ACCESSORY", "스카프",   50,  "COMMON", "accessory/scarf.png",       None,           None),
            (uuid.UUID("10000000-0000-0000-0000-000000000044"), "ACCESSORY", "선글라스", 120, "RARE",   "accessory/sunglasses.png",  "COIN_BOOST",   10),
            (uuid.UUID("10000000-0000-0000-0000-000000000045"), "ACCESSORY", "이어폰",   150, "RARE",   "accessory/earphones.png",   "VERIFY_BONUS", 5),
            (uuid.UUID("10000000-0000-0000-0000-000000000046"), "ACCESSORY", "천사날개", 400, "EPIC",   "accessory/angel_wings.png", "COIN_BOOST",   25),
            (uuid.UUID("10000000-0000-0000-0000-000000000047"), "ACCESSORY", "신문",         40,  "COMMON", "accessory/newspaper.png",      None,           None),
            (uuid.UUID("10000000-0000-0000-0000-000000000048"), "ACCESSORY", "노란오리물총",  120, "RARE",   "accessory/duck_watergun.png",  "COIN_BOOST",   10),
            (uuid.UUID("10000000-0000-0000-0000-000000000049"), "ACCESSORY", "노트북",       150, "RARE",   "accessory/laptop.png",         "VERIFY_BONUS", 5),
            (uuid.UUID("10000000-0000-0000-0000-000000000050"), "ACCESSORY", "연필",         50,  "COMMON", "accessory/pencil.png",         None,           None),
        ]

        for item_id, category, name, price, rarity, asset_key, effect_type, effect_value in items_data:
            await db.execute(
                text(
                    "INSERT INTO items "
                    "(id, name, category, price, rarity, asset_key, is_active, sort_order, effect_type, effect_value) "
                    "VALUES (:id, :name, :category, :price, :rarity, :asset_key, true, :sort_order, :effect_type, :effect_value)"
                ),
                {
                    "id": str(item_id),
                    "name": name,
                    "category": category,
                    "price": price,
                    "rarity": rarity,
                    "asset_key": asset_key,
                    "sort_order": price,
                    "effect_type": effect_type,
                    "effect_value": effect_value,
                },
            )

        # ── GemTransactions (유저별 초기 코인 지급) ──
        gem_data = [
            (USER_1_ID, 500, "DAILY_LOGIN"),   # 김철수 500코인
            (USER_2_ID, 300, "DAILY_LOGIN"),   # 이영희 300코인
            (USER_3_ID, 100, "DAILY_LOGIN"),   # 박지민 100코인
        ]
        for uid, amount, reason in gem_data:
            await db.execute(
                text(
                    "INSERT INTO gem_transactions (id, user_id, amount, reason) "
                    "VALUES (:id, :user_id, :amount, :reason)"
                ),
                {
                    "id": str(uuid.uuid4()),
                    "user_id": str(uid),
                    "amount": amount,
                    "reason": reason,
                },
            )

        # ── UserItems ──
        # 김철수: 캡모자, 흰티, 청바지, 운동화
        # 이영희: 비니, 후드티, 부츠
        # 박지민: 머리띠
        user_items_data = [
            (USER_1_ID, ITEM_CAP),
            (USER_1_ID, ITEM_WHITE_TEE),
            (USER_1_ID, ITEM_JEANS),
            (USER_1_ID, ITEM_SNEAKERS),
            (USER_2_ID, ITEM_BEANIE),
            (USER_2_ID, ITEM_HOODIE),
            (USER_2_ID, ITEM_BOOTS),
            (USER_3_ID, ITEM_HEADBAND),
        ]
        for uid, iid in user_items_data:
            await db.execute(
                text(
                    "INSERT INTO user_items (id, user_id, item_id) "
                    "VALUES (:id, :user_id, :item_id)"
                ),
                {
                    "id": str(uuid.uuid4()),
                    "user_id": str(uid),
                    "item_id": str(iid),
                },
            )

        # ── CharacterEquips ──
        # 김철수: 전부 장착
        await db.execute(
            text(
                "INSERT INTO character_equips "
                "(user_id, hat_item_id, top_item_id, bottom_item_id, shoes_item_id, accessory_item_id) "
                "VALUES (:user_id, :hat, :top, :bottom, :shoes, :accessory)"
            ),
            {
                "user_id": str(USER_1_ID),
                "hat": str(ITEM_CAP),
                "top": str(ITEM_WHITE_TEE),
                "bottom": str(ITEM_JEANS),
                "shoes": str(ITEM_SNEAKERS),
                "accessory": None,
            },
        )
        # 이영희: 비니 + 후드티만 장착
        await db.execute(
            text(
                "INSERT INTO character_equips "
                "(user_id, hat_item_id, top_item_id, bottom_item_id, shoes_item_id, accessory_item_id) "
                "VALUES (:user_id, :hat, :top, :bottom, :shoes, :accessory)"
            ),
            {
                "user_id": str(USER_2_ID),
                "hat": str(ITEM_BEANIE),
                "top": str(ITEM_HOODIE),
                "bottom": None,
                "shoes": None,
                "accessory": None,
            },
        )
        # 박지민: 머리띠만 장착
        await db.execute(
            text(
                "INSERT INTO character_equips "
                "(user_id, hat_item_id, top_item_id, bottom_item_id, shoes_item_id, accessory_item_id) "
                "VALUES (:user_id, :hat, :top, :bottom, :shoes, :accessory)"
            ),
            {
                "user_id": str(USER_3_ID),
                "hat": str(ITEM_HEADBAND),
                "top": None,
                "bottom": None,
                "shoes": None,
                "accessory": None,
            },
        )

        await db.commit()
        print("Seed data inserted successfully!")
        print(f"  Users: 3 (김철수, 이영희, 박지민)")
        print(f"  Challenge: 운동 30일 (2026-03-05 ~ 2026-04-03)")
        print(f"  Members: 3")
        print(f"  Verifications: 46 (16+14+16)")
        print(f"  DayCompletions: 14 (3/5~3/18)")
        print(f"  Items: 34 (HAT/TOP/BOTTOM/SHOES 6 each + ACCESSORY 10)")
        print(f"  GemTransactions: 3 (김철수 500, 이영희 300, 박지민 100)")
        print(f"  UserItems: 8 (김철수 4, 이영희 3, 박지민 1)")
        print(f"  CharacterEquips: 3")
        print(f"\nTest tokens (use as Bearer <uuid>):")
        print(f"  김철수: {USER_1_ID}")
        print(f"  이영희: {USER_2_ID}")
        print(f"  박지민: {USER_3_ID}")


if __name__ == "__main__":
    asyncio.run(seed())
