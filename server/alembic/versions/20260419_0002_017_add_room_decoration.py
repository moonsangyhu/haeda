"""add room decoration tables and item fields

Revision ID: 017
Revises: 016
Create Date: 2026-04-19 00:02:00.000000

"""
from typing import Sequence, Union
import uuid

import sqlalchemy as sa
from alembic import op

revision: str = "017"
down_revision: Union[str, None] = "016"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. items 테이블 컬럼 추가
    op.add_column("items", sa.Column("is_limited", sa.Boolean(), server_default="false", nullable=False))
    op.add_column("items", sa.Column("reward_trigger", sa.String(64), nullable=True))

    # 2. room_equip_mr 테이블 생성
    op.create_table(
        "room_equip_mr",
        sa.Column("user_id", sa.UUID(as_uuid=True), sa.ForeignKey("users.id"), primary_key=True),
        sa.Column("wall_item_id", sa.UUID(as_uuid=True), sa.ForeignKey("items.id"), nullable=True),
        sa.Column("ceiling_item_id", sa.UUID(as_uuid=True), sa.ForeignKey("items.id"), nullable=True),
        sa.Column("window_item_id", sa.UUID(as_uuid=True), sa.ForeignKey("items.id"), nullable=True),
        sa.Column("shelf_item_id", sa.UUID(as_uuid=True), sa.ForeignKey("items.id"), nullable=True),
        sa.Column("plant_item_id", sa.UUID(as_uuid=True), sa.ForeignKey("items.id"), nullable=True),
        sa.Column("desk_item_id", sa.UUID(as_uuid=True), sa.ForeignKey("items.id"), nullable=True),
        sa.Column("rug_item_id", sa.UUID(as_uuid=True), sa.ForeignKey("items.id"), nullable=True),
        sa.Column("floor_item_id", sa.UUID(as_uuid=True), sa.ForeignKey("items.id"), nullable=True),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
    )

    # 3. room_equip_cr 테이블 생성
    op.create_table(
        "room_equip_cr",
        sa.Column("challenge_id", sa.UUID(as_uuid=True), sa.ForeignKey("challenges.id"), primary_key=True),
        sa.Column("wall_item_id", sa.UUID(as_uuid=True), sa.ForeignKey("items.id"), nullable=True),
        sa.Column("window_item_id", sa.UUID(as_uuid=True), sa.ForeignKey("items.id"), nullable=True),
        sa.Column("calendar_item_id", sa.UUID(as_uuid=True), sa.ForeignKey("items.id"), nullable=True),
        sa.Column("board_item_id", sa.UUID(as_uuid=True), sa.ForeignKey("items.id"), nullable=True),
        sa.Column("sofa_item_id", sa.UUID(as_uuid=True), sa.ForeignKey("items.id"), nullable=True),
        sa.Column("floor_item_id", sa.UUID(as_uuid=True), sa.ForeignKey("items.id"), nullable=True),
        sa.Column("updated_by_user_id", sa.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
    )

    # 4. room_equip_cr_signature 테이블 생성
    op.create_table(
        "room_equip_cr_signature",
        sa.Column("id", sa.UUID(as_uuid=True), primary_key=True),
        sa.Column("challenge_id", sa.UUID(as_uuid=True), sa.ForeignKey("challenges.id"), nullable=False),
        sa.Column("user_id", sa.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("signature_item_id", sa.UUID(as_uuid=True), sa.ForeignKey("items.id"), nullable=True),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_unique_constraint(
        "uq_room_equip_cr_signature_member",
        "room_equip_cr_signature",
        ["challenge_id", "user_id"],
    )
    op.create_index("ix_room_equip_cr_signature_challenge", "room_equip_cr_signature", ["challenge_id"])
    op.create_index("ix_room_equip_cr_signature_user", "room_equip_cr_signature", ["user_id"])

    # 5. 시드 데이터 - 미니룸 아이템 (8 슬롯 × 2~3개)
    items_table = sa.table(
        "items",
        sa.column("id", sa.UUID(as_uuid=True)),
        sa.column("name", sa.String),
        sa.column("category", sa.String),
        sa.column("price", sa.Integer),
        sa.column("rarity", sa.String),
        sa.column("asset_key", sa.String),
        sa.column("is_active", sa.Boolean),
        sa.column("is_limited", sa.Boolean),
        sa.column("reward_trigger", sa.String),
        sa.column("sort_order", sa.Integer),
    )

    mr_items = [
        # MR_WALL (2개)
        {"id": uuid.UUID("00000001-0000-0000-0000-000000000001"), "name": "라벤더 벽지", "category": "MR_WALL", "price": 0, "rarity": "COMMON", "asset_key": "mr/wall_lavender", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 0},
        {"id": uuid.UUID("00000001-0000-0000-0000-000000000002"), "name": "민트 벽지", "category": "MR_WALL", "price": 300, "rarity": "COMMON", "asset_key": "mr/wall_mint", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 1},
        # MR_CEILING (2개)
        {"id": uuid.UUID("00000001-0000-0000-0000-000000000011"), "name": "흰 천장", "category": "MR_CEILING", "price": 0, "rarity": "COMMON", "asset_key": "mr/ceiling_white", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 0},
        {"id": uuid.UUID("00000001-0000-0000-0000-000000000012"), "name": "별자리 천장", "category": "MR_CEILING", "price": 500, "rarity": "COMMON", "asset_key": "mr/ceiling_stars", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 1},
        # MR_WINDOW (2개)
        {"id": uuid.UUID("00000001-0000-0000-0000-000000000021"), "name": "나무 창문", "category": "MR_WINDOW", "price": 0, "rarity": "COMMON", "asset_key": "mr/window_wood", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 0},
        {"id": uuid.UUID("00000001-0000-0000-0000-000000000022"), "name": "아치 창문", "category": "MR_WINDOW", "price": 400, "rarity": "COMMON", "asset_key": "mr/window_arch", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 1},
        # MR_SHELF (2개)
        {"id": uuid.UUID("00000001-0000-0000-0000-000000000031"), "name": "원목 선반", "category": "MR_SHELF", "price": 0, "rarity": "COMMON", "asset_key": "mr/shelf_wood", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 0},
        {"id": uuid.UUID("00000001-0000-0000-0000-000000000032"), "name": "흰 선반", "category": "MR_SHELF", "price": 350, "rarity": "COMMON", "asset_key": "mr/shelf_white", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 1},
        # MR_PLANT (2개)
        {"id": uuid.UUID("00000001-0000-0000-0000-000000000041"), "name": "선인장", "category": "MR_PLANT", "price": 0, "rarity": "COMMON", "asset_key": "mr/plant_cactus", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 0},
        {"id": uuid.UUID("00000001-0000-0000-0000-000000000042"), "name": "몬스테라", "category": "MR_PLANT", "price": 400, "rarity": "COMMON", "asset_key": "mr/plant_monstera", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 1},
        # MR_DESK (2개)
        {"id": uuid.UUID("00000001-0000-0000-0000-000000000051"), "name": "원목 책상", "category": "MR_DESK", "price": 0, "rarity": "COMMON", "asset_key": "mr/desk_wood", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 0},
        {"id": uuid.UUID("00000001-0000-0000-0000-000000000052"), "name": "유리 책상", "category": "MR_DESK", "price": 500, "rarity": "COMMON", "asset_key": "mr/desk_glass", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 1},
        # MR_RUG (2개)
        {"id": uuid.UUID("00000001-0000-0000-0000-000000000061"), "name": "체크 러그", "category": "MR_RUG", "price": 0, "rarity": "COMMON", "asset_key": "mr/rug_check", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 0},
        {"id": uuid.UUID("00000001-0000-0000-0000-000000000062"), "name": "줄무늬 러그", "category": "MR_RUG", "price": 300, "rarity": "COMMON", "asset_key": "mr/rug_stripe", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 1},
        # MR_FLOOR (2개)
        {"id": uuid.UUID("00000001-0000-0000-0000-000000000071"), "name": "원목 바닥", "category": "MR_FLOOR", "price": 0, "rarity": "COMMON", "asset_key": "mr/floor_wood", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 0},
        {"id": uuid.UUID("00000001-0000-0000-0000-000000000072"), "name": "타일 바닥", "category": "MR_FLOOR", "price": 400, "rarity": "COMMON", "asset_key": "mr/floor_tile", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 1},
        # CR_WALL (2개)
        {"id": uuid.UUID("00000002-0000-0000-0000-000000000001"), "name": "벽돌 벽", "category": "CR_WALL", "price": 0, "rarity": "COMMON", "asset_key": "cr/wall_brick", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 0},
        {"id": uuid.UUID("00000002-0000-0000-0000-000000000002"), "name": "파스텔 벽", "category": "CR_WALL", "price": 300, "rarity": "COMMON", "asset_key": "cr/wall_pastel", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 1},
        # CR_WINDOW (2개)
        {"id": uuid.UUID("00000002-0000-0000-0000-000000000011"), "name": "큰 창문", "category": "CR_WINDOW", "price": 0, "rarity": "COMMON", "asset_key": "cr/window_large", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 0},
        {"id": uuid.UUID("00000002-0000-0000-0000-000000000012"), "name": "둥근 창문", "category": "CR_WINDOW", "price": 350, "rarity": "COMMON", "asset_key": "cr/window_round", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 1},
        # CR_CALENDAR (2개)
        {"id": uuid.UUID("00000002-0000-0000-0000-000000000021"), "name": "기본 달력", "category": "CR_CALENDAR", "price": 0, "rarity": "COMMON", "asset_key": "cr/calendar_basic", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 0},
        {"id": uuid.UUID("00000002-0000-0000-0000-000000000022"), "name": "플라워 달력", "category": "CR_CALENDAR", "price": 400, "rarity": "COMMON", "asset_key": "cr/calendar_flower", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 1},
        # CR_BOARD (2개)
        {"id": uuid.UUID("00000002-0000-0000-0000-000000000031"), "name": "원목 게시판", "category": "CR_BOARD", "price": 0, "rarity": "COMMON", "asset_key": "cr/board_wood", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 0},
        {"id": uuid.UUID("00000002-0000-0000-0000-000000000032"), "name": "블랙보드", "category": "CR_BOARD", "price": 300, "rarity": "COMMON", "asset_key": "cr/board_black", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 1},
        # CR_SOFA (2개)
        {"id": uuid.UUID("00000002-0000-0000-0000-000000000041"), "name": "패브릭 소파", "category": "CR_SOFA", "price": 0, "rarity": "COMMON", "asset_key": "cr/sofa_fabric", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 0},
        {"id": uuid.UUID("00000002-0000-0000-0000-000000000042"), "name": "가죽 소파", "category": "CR_SOFA", "price": 500, "rarity": "COMMON", "asset_key": "cr/sofa_leather", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 1},
        # CR_FLOOR (2개)
        {"id": uuid.UUID("00000002-0000-0000-0000-000000000051"), "name": "원목 바닥", "category": "CR_FLOOR", "price": 0, "rarity": "COMMON", "asset_key": "cr/floor_wood", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 0},
        {"id": uuid.UUID("00000002-0000-0000-0000-000000000052"), "name": "타일 바닥", "category": "CR_FLOOR", "price": 400, "rarity": "COMMON", "asset_key": "cr/floor_tile", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 1},
        # SIGNATURE (3개)
        {"id": uuid.UUID("00000003-0000-0000-0000-000000000001"), "name": "강아지", "category": "SIGNATURE", "price": 0, "rarity": "COMMON", "asset_key": "sig/dog", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 0},
        {"id": uuid.UUID("00000003-0000-0000-0000-000000000002"), "name": "풍선", "category": "SIGNATURE", "price": 300, "rarity": "COMMON", "asset_key": "sig/balloon", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 1},
        {"id": uuid.UUID("00000003-0000-0000-0000-000000000003"), "name": "트로피", "category": "SIGNATURE", "price": 500, "rarity": "COMMON", "asset_key": "sig/trophy", "is_active": True, "is_limited": False, "reward_trigger": "SHOP", "sort_order": 2},
    ]

    op.bulk_insert(items_table, mr_items)


def downgrade() -> None:
    # 시드 데이터 삭제 (UUID 목록)
    seed_ids = [
        "00000001-0000-0000-0000-000000000001", "00000001-0000-0000-0000-000000000002",
        "00000001-0000-0000-0000-000000000011", "00000001-0000-0000-0000-000000000012",
        "00000001-0000-0000-0000-000000000021", "00000001-0000-0000-0000-000000000022",
        "00000001-0000-0000-0000-000000000031", "00000001-0000-0000-0000-000000000032",
        "00000001-0000-0000-0000-000000000041", "00000001-0000-0000-0000-000000000042",
        "00000001-0000-0000-0000-000000000051", "00000001-0000-0000-0000-000000000052",
        "00000001-0000-0000-0000-000000000061", "00000001-0000-0000-0000-000000000062",
        "00000001-0000-0000-0000-000000000071", "00000001-0000-0000-0000-000000000072",
        "00000002-0000-0000-0000-000000000001", "00000002-0000-0000-0000-000000000002",
        "00000002-0000-0000-0000-000000000011", "00000002-0000-0000-0000-000000000012",
        "00000002-0000-0000-0000-000000000021", "00000002-0000-0000-0000-000000000022",
        "00000002-0000-0000-0000-000000000031", "00000002-0000-0000-0000-000000000032",
        "00000002-0000-0000-0000-000000000041", "00000002-0000-0000-0000-000000000042",
        "00000002-0000-0000-0000-000000000051", "00000002-0000-0000-0000-000000000052",
        "00000003-0000-0000-0000-000000000001", "00000003-0000-0000-0000-000000000002",
        "00000003-0000-0000-0000-000000000003",
    ]
    ids_str = ", ".join(f"'{i}'" for i in seed_ids)
    op.execute(sa.text(f"DELETE FROM items WHERE id IN ({ids_str})"))

    # 테이블 삭제
    op.drop_index("ix_room_equip_cr_signature_user", table_name="room_equip_cr_signature")
    op.drop_index("ix_room_equip_cr_signature_challenge", table_name="room_equip_cr_signature")
    op.drop_constraint("uq_room_equip_cr_signature_member", "room_equip_cr_signature", type_="unique")
    op.drop_table("room_equip_cr_signature")
    op.drop_table("room_equip_cr")
    op.drop_table("room_equip_mr")

    # 컬럼 삭제
    op.drop_column("items", "reward_trigger")
    op.drop_column("items", "is_limited")
