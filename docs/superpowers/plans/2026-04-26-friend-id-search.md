# 친구 ID(`닉네임#숫자`) 검색·추가 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Discord 스타일의 `닉네임#5자리숫자` ID 를 도입해, 정확한 ID 로 친구를 검색·추가하고 자기 ID 를 설정·마이페이지에서 확인·복사할 수 있게 한다.

**Architecture:** `users` 테이블에 `discriminator VARCHAR(5)` + `UNIQUE(nickname, discriminator)` 추가. 가입 시점에 nickname 그룹 안에서 unique 한 5자리 랜덤 값 발급. 새 엔드포인트 `POST /users/search-by-id` 로 정확 일치 검색. 프론트는 `ContactSearchScreen` 에 ID 입력 블록 추가, `SettingsScreen` 에 "내 ID" 섹션 + 마이페이지 상단에 닉네임#숫자 헤더 추가.

**Tech Stack:** FastAPI + SQLAlchemy 2.0 async + Alembic + Pydantic v2, Flutter + Riverpod + freezed + dio, Postgres.

**Spec:** `docs/superpowers/specs/2026-04-26-friend-id-search-design.md`

---

## Conventions (read first — supersedes inline test code below)

이 레포의 실제 테스트 환경에 맞춰 **본 plan 의 모든 test 코드 인용을 보정해야 한다**. 인라인 코드는 의도 표현용 의사 예제이고, 실제 작성 시 다음 규칙을 따른다:

1. **DB 백엔드는 SQLite in-memory** (`server/tests/conftest.py`).
   - PostgreSQL-전용 정규식 (`~` 연산자), `psql -c` 검증, `pg_*` 함수, JSONB 등은 모델 / 테스트에 사용 금지.
   - `discriminator` 의 5자리 숫자 형식은 **Pydantic 스키마 (Field pattern) 가 강제**하고, **postgres CHECK 제약은 Alembic 마이그레이션에만 둔다**. SQLAlchemy 모델 정의에서 `CheckConstraint("discriminator ~ ...")` 를 **포함하지 않는다** (SQLite 가 `~` 를 모르므로 `Base.metadata.create_all` 실행 시 타입 에러).
   - 모델의 `__table_args__` 는 `UniqueConstraint("nickname", "discriminator", ...)` 만 둔다.

2. **Fixture 매핑** (plan 인라인 코드에서 → 실제):
   - `db` → **`db_session`** (`server/tests/conftest.py` 정의)
   - `auth_user` → **`user`** (이미 conftest.py 에 있음, kakao_id=1001, nickname="테스터")
   - `auth_headers: dict` → 직접 작성 `headers={"Authorization": f"Bearer {user.id}"}`
   - 추가 사용자가 필요하면 `other_user` (kakao_id=1002, nickname="다른사람") 또는 인라인 생성

3. **Migration 검증 테스트 (`test_migration_discriminator_backfill.py`) 는 작성 X.** SQLite 환경에서 의미 없음. 마이그레이션은 `docker compose exec backend ... alembic upgrade head` + `psql` 검증으로 수동 확인 (Task 3 step).

4. **Backend 명령**:
   - 테스트: 호스트의 `server/.venv/bin/pytest ...` (컨테이너에는 dev 의존성 미설치)
   - Alembic: 컨테이너 안에서 `docker compose exec -T backend bash -c ".venv/bin/alembic upgrade head"` 또는 호스트에서 `cd server && .venv/bin/alembic ...`
   - DB 검증: `docker compose exec -T db psql -U haeda -d haeda -c "..."` — 단, `haeda` 가 실제 DB 명/유저명인지 `docker compose config` 로 한 번 확인

5. **인증 라우터 테스트 시 prefix**: `/api/v1` 프리픽스가 붙는지 기존 `tests/test_*.py` 에서 확인. (예: `await client.get("/api/v1/me", ...)` 일 수도 있음.) 새 라우터 테스트도 같은 패턴.

6. **사전 실패 테스트 1개 무시**: `test_room_equip.py::test_member_clear_signature` 는 본 작업 이전부터 fail 상태. 베이스라인이며 수정 대상 아님. 회귀 테스트 시에는 `--ignore=tests/test_room_equip.py` 또는 명시 deselect.

---

## File Structure

### Server (create / modify)

| 경로 | 책임 |
|------|------|
| `server/alembic/versions/20260426_0001_020_add_user_discriminator.py` (신규) | discriminator 컬럼 + 백필 + 제약 |
| `server/app/models/user.py` (수정) | `discriminator` 매핑 + UniqueConstraint + CheckConstraint |
| `server/app/services/discriminator_service.py` (신규) | nickname 그룹 안에서 unique 한 5자리 랜덤 발급 |
| `server/app/services/auth_service.py` (수정) | `login_or_register` 에서 discriminator 발급 호출 |
| `server/app/services/friend_service.py` (수정) | `compute_friendship_status` 헬퍼 + `match_contacts` 응답에 discriminator 포함 |
| `server/app/services/user_search_service.py` (신규) | `search_by_id` 비즈니스 로직 |
| `server/app/schemas/user.py` (수정) | `UserBrief` / `UserWithIsNew` / `ProfileUpdateResponse` 에 `discriminator` 필드 |
| `server/app/schemas/friendship.py` (수정) | `ContactMatchItem` 에 `discriminator` 필드 |
| `server/app/schemas/user_search.py` (신규) | `UserSearchByIdRequest`, `UserSearchByIdResponse` |
| `server/app/routers/users.py` (수정) | `POST /users/search-by-id` 엔드포인트 |
| `server/app/routers/me.py` (수정) | `/me` 응답에 `discriminator` 포함 |

### Server tests (신규)

| 경로 | 대상 |
|------|------|
| `server/tests/services/test_discriminator_service.py` | 발급 로직 단위 |
| `server/tests/services/test_auth_service_discriminator.py` | 가입 시 발급 |
| `server/tests/routers/test_users_search_by_id.py` | 신규 엔드포인트 |
| `server/tests/routers/test_me_includes_discriminator.py` | /me 응답 |
| `server/tests/routers/test_contact_match_includes_discriminator.py` | /friends/contact-match 응답 |

### App (수정)

| 경로 | 책임 |
|------|------|
| `app/lib/features/auth/providers/auth_provider.dart` | `AuthUser.discriminator` 추가 + `/me` 파싱 |
| `app/lib/features/friends/models/friend_data.dart` | `ContactMatchItem.discriminator` |
| `app/lib/features/friends/screens/contact_search_screen.dart` | ID 검색 입력 블록 + self 케이스 처리 |
| `app/lib/features/friends/utils/user_id_format.dart` (신규) | `parseUserId` / `formatUserId` 유틸 + 정규식 |
| `app/lib/features/settings/screens/settings_screen.dart` | "내 ID" 섹션 + 프로필 카드 닉네임 옆 표시 |
| `app/lib/features/my_page/screens/my_page_screen.dart` | 상단에 닉네임#숫자 + 복사 버튼 헤더 |

### App tests (신규)

| 경로 | 대상 |
|------|------|
| `app/test/features/friends/utils/user_id_format_test.dart` | parse/format 단위 |
| `app/test/features/friends/screens/contact_search_screen_id_test.dart` | ID 입력 시나리오 위젯 |
| `app/test/features/settings/screens/settings_my_id_test.dart` | 내 ID 표시 + 복사 위젯 |

### Docs (소스-오브-트루스)

| 경로 | 변경 |
|------|------|
| `docs/domain-model.md` | §2.1 User 표에 `discriminator VARCHAR(5)` row + UNIQUE/CHECK 비고 |
| `docs/api-contract.md` | user 스키마들에 `discriminator` 필드 + 신규 `POST /users/search-by-id` 섹션 |

---

## Pre-flight

- [ ] **Step 0.1: 컨테이너 / DB 기동 확인**

Run:
```bash
docker compose ps
```

Expected: `backend` 와 `db` 컨테이너 모두 `Up`. 없으면:
```bash
docker compose up -d db backend
```

- [ ] **Step 0.2: 현재 alembic head 확인**

Run:
```bash
docker compose exec backend alembic current
```

Expected: `019 (head)` 또는 그 이상. 다른 head 가 있으면 plan 실행 전에 보고.

- [ ] **Step 0.3: 베이스라인 테스트 통과 확인**

Run:
```bash
docker compose exec backend pytest -x -q
```

Expected: 모든 테스트 PASS. 실패가 있으면 plan 실행 전에 보고하고 멈춤.

---

## Task 1: 도메인 / API contract 문서 업데이트

문서 우선 (코드 작성 시 docs-guard 가 막으니 먼저 갱신).

**Files:**
- Modify: `docs/domain-model.md` (§2.1 User 표)
- Modify: `docs/api-contract.md`

- [ ] **Step 1.1: domain-model.md User 표에 discriminator row 추가**

`docs/domain-model.md` §2.1 User 표 — `nickname` row 바로 아래에 다음 row 를 삽입:

```markdown
| discriminator | VARCHAR(5) | NOT NULL | 5자리 숫자 (`'10000'`–`'99999'`). `(nickname, discriminator)` UNIQUE, CHECK `~ '^[0-9]{5}$'` |
```

- [ ] **Step 1.2: api-contract.md user 응답 스키마에 discriminator 필드 추가**

`docs/api-contract.md` 안의 모든 user 응답 표현에 `discriminator: string` 필드를 추가한다 (예시 값 `"43217"`):

- `GET /me` 응답
- `/friends/contact-match` 응답의 매치 항목
- friends list / pending requests 등 user 표현이 등장하는 모든 위치
- `POST /users/search-by-id` (다음 step)

- [ ] **Step 1.3: api-contract.md 에 POST /users/search-by-id 섹션 추가**

api-contract.md 의 users 섹션(또는 friends 섹션 인접) 에 다음 명세를 추가:

```markdown
### POST `/users/search-by-id` — 닉네임#숫자 ID 로 사용자 검색

요청:
```json
{
  "nickname": "홍길동",
  "discriminator": "43217"
}
```

200 OK:
```json
{
  "data": {
    "user_id": "uuid",
    "nickname": "홍길동",
    "discriminator": "43217",
    "profile_image_url": "https://...",
    "friendship_status": "none" | "pending" | "accepted" | "self"
  }
}
```

에러:
- 400 `INVALID_ID_FORMAT` — discriminator 형식 위반
- 401 `UNAUTHORIZED`
- 404 `USER_NOT_FOUND` — 일치 사용자 없음
```

- [ ] **Step 1.4: 문서 변경 커밋**

```bash
git add docs/domain-model.md docs/api-contract.md
git commit -m "docs: add user discriminator and POST /users/search-by-id"
```

---

## Task 2: User 모델에 discriminator 필드 추가 (마이그레이션 전)

> Alembic autogenerate 가 모델을 참조하므로 모델을 먼저 수정한다. 단, 이 단계에서는 NULLABLE 로 두고 Task 3 마이그레이션이 백필 후 NOT NULL 로 승격한다.

**Files:**
- Modify: `server/app/models/user.py`

- [ ] **Step 2.1: User 모델에 discriminator 컬럼 + 제약 추가**

`server/app/models/user.py` 를 다음으로 갱신:

```python
import uuid
from datetime import datetime

from sqlalchemy import BigInteger, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.models.base import Base


class User(Base):
    __tablename__ = "users"
    __table_args__ = (
        UniqueConstraint("nickname", "discriminator", name="uq_users_nickname_discriminator"),
        # CheckConstraint 는 postgres-only 정규식 (`~`) 이라 SQLite 테스트와 호환 X — 마이그레이션에만 둔다.
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    kakao_id: Mapped[int] = mapped_column(BigInteger, unique=True, nullable=False)
    nickname: Mapped[str] = mapped_column(String(30), nullable=False)
    discriminator: Mapped[str] = mapped_column(String(5), nullable=False)
    profile_image_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    background_color: Mapped[str | None] = mapped_column(String(9), nullable=True)
    phone_number: Mapped[str | None] = mapped_column(String(20), nullable=True, unique=True)
    created_at: Mapped[datetime] = mapped_column(
        nullable=False, server_default=func.now()
    )

    # relationships
    created_challenges: Mapped[list["Challenge"]] = relationship(
        "Challenge", back_populates="creator", foreign_keys="Challenge.creator_id"
    )
    memberships: Mapped[list["ChallengeMember"]] = relationship(
        "ChallengeMember", back_populates="user"
    )
    verifications: Mapped[list["Verification"]] = relationship(
        "Verification", back_populates="user"
    )
    gem_transactions: Mapped[list["GemTransaction"]] = relationship(
        "GemTransaction", back_populates="user"
    )
    user_items: Mapped[list["UserItem"]] = relationship(
        "UserItem", back_populates="user"
    )
    character_equip: Mapped["CharacterEquip | None"] = relationship(
        "CharacterEquip", back_populates="user", uselist=False
    )
```

> 주의: 이 시점에 마이그레이션이 아직 실행되지 않아 컬럼이 없으므로 ORM 쿼리는 깨진다. 다음 Task 3 마이그레이션을 즉시 이어서 진행한다 (커밋 분리).

- [ ] **Step 2.2: 모델 변경만 커밋 (아직 적용 X)**

```bash
git add server/app/models/user.py
git commit -m "feat(server): add User.discriminator field with unique+check constraints"
```

---

## Task 3: Alembic 마이그레이션 (컬럼 추가 + 백필 + NOT NULL)

**Files:**
- Create: `server/alembic/versions/20260426_0001_020_add_user_discriminator.py`

- [ ] **Step 3.1: 마이그레이션 파일 작성**

`server/alembic/versions/20260426_0001_020_add_user_discriminator.py` 를 다음 내용으로 신규 작성:

```python
"""add user.discriminator with backfill

Revision ID: 020
Revises: 019
Create Date: 2026-04-26 00:01:00.000000

"""
import random
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "020"
down_revision: Union[str, None] = "019"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1) NULLABLE 로 컬럼 추가
    op.add_column(
        "users",
        sa.Column("discriminator", sa.String(length=5), nullable=True),
    )

    # 2) 닉네임 그룹 단위로 백필
    bind = op.get_bind()
    rows = bind.execute(
        sa.text("SELECT id, nickname FROM users ORDER BY created_at")
    ).fetchall()

    used_per_nickname: dict[str, set[str]] = {}
    rng = random.Random(20260426)  # 결정성 확보 (재실행 시 동일 결과)
    for row in rows:
        nickname = row.nickname
        used = used_per_nickname.setdefault(nickname, set())
        for _ in range(50):
            candidate = f"{rng.randint(10000, 99999)}"
            if candidate not in used:
                used.add(candidate)
                bind.execute(
                    sa.text("UPDATE users SET discriminator = :d WHERE id = :id"),
                    {"d": candidate, "id": row.id},
                )
                break
        else:
            raise RuntimeError(
                f"Could not assign discriminator for nickname={nickname!r}"
            )

    # 3) NOT NULL + UNIQUE + CHECK 제약 추가
    op.alter_column("users", "discriminator", nullable=False)
    op.create_unique_constraint(
        "uq_users_nickname_discriminator",
        "users",
        ["nickname", "discriminator"],
    )
    op.create_check_constraint(
        "ck_users_discriminator_format",
        "users",
        "discriminator ~ '^[0-9]{5}$'",
    )


def downgrade() -> None:
    op.drop_constraint(
        "ck_users_discriminator_format", "users", type_="check"
    )
    op.drop_constraint(
        "uq_users_nickname_discriminator", "users", type_="unique"
    )
    op.drop_column("users", "discriminator")
```

- [ ] **Step 3.2: 마이그레이션 적용**

Run:
```bash
docker compose exec backend alembic upgrade head
```

Expected:
```
INFO  [alembic.runtime.migration] Running upgrade 019 -> 020, add user.discriminator with backfill
```

- [ ] **Step 3.3: DB 상태 검증**

Run:
```bash
docker compose exec db psql -U haeda -d haeda -c "SELECT id, nickname, discriminator FROM users ORDER BY created_at LIMIT 10;"
docker compose exec db psql -U haeda -d haeda -c "SELECT COUNT(*) FROM users WHERE discriminator IS NULL;"
docker compose exec db psql -U haeda -d haeda -c "SELECT nickname, discriminator, COUNT(*) FROM users GROUP BY nickname, discriminator HAVING COUNT(*) > 1;"
```

Expected:
- 모든 행이 5자리 숫자 보유
- NULL 카운트 0
- 중복 (nickname, discriminator) 없음 (빈 결과)

- [ ] **Step 3.4: 마이그레이션 커밋**

```bash
git add server/alembic/versions/20260426_0001_020_add_user_discriminator.py
git commit -m "feat(server): migration to add+backfill user.discriminator"
```

---

## Task 4: discriminator 발급 서비스 (신규)

**Files:**
- Create: `server/app/services/discriminator_service.py`
- Create: `server/tests/services/test_discriminator_service.py`

- [ ] **Step 4.1: 실패하는 테스트 작성**

`server/tests/services/test_discriminator_service.py`:

```python
import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.services.discriminator_service import (
    DiscriminatorExhausted,
    generate_discriminator,
)


@pytest.mark.asyncio
async def test_generate_for_unused_nickname(db: AsyncSession):
    result = await generate_discriminator(db, nickname="첫사용자")
    assert result.isdigit()
    assert len(result) == 5
    assert 10000 <= int(result) <= 99999


@pytest.mark.asyncio
async def test_avoids_existing_discriminator(db: AsyncSession, monkeypatch):
    # 같은 닉네임 + "10001" 이 이미 존재하는 상황
    db.add(User(kakao_id=1, nickname="중복", discriminator="10001"))
    await db.commit()

    # random 이 항상 10001 → 10002 순으로 부르도록 강제
    sequence = iter(["10001", "10002"])
    monkeypatch.setattr(
        "app.services.discriminator_service._random_5digit",
        lambda: next(sequence),
    )

    result = await generate_discriminator(db, nickname="중복")
    assert result == "10002"


@pytest.mark.asyncio
async def test_raises_when_all_attempts_collide(db: AsyncSession, monkeypatch):
    db.add(User(kakao_id=2, nickname="포화", discriminator="55555"))
    await db.commit()

    # 50회 모두 같은 값 → 충돌 → exhausted
    monkeypatch.setattr(
        "app.services.discriminator_service._random_5digit",
        lambda: "55555",
    )
    monkeypatch.setattr(
        "app.services.discriminator_service.MAX_ATTEMPTS", 3
    )

    with pytest.raises(DiscriminatorExhausted):
        await generate_discriminator(db, nickname="포화")
```

- [ ] **Step 4.2: 테스트 실패 확인**

Run:
```bash
docker compose exec backend pytest server/tests/services/test_discriminator_service.py -v
```

Expected: `ImportError` / `ModuleNotFoundError` (서비스 파일 미존재).

- [ ] **Step 4.3: 최소 구현**

`server/app/services/discriminator_service.py`:

```python
import random

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User


MAX_ATTEMPTS = 50


class DiscriminatorExhausted(Exception):
    """닉네임 그룹 내에서 사용 가능한 discriminator 를 찾지 못함."""


def _random_5digit() -> str:
    return f"{random.randint(10000, 99999)}"


async def generate_discriminator(db: AsyncSession, *, nickname: str) -> str:
    used_stmt = select(User.discriminator).where(User.nickname == nickname)
    used_result = await db.execute(used_stmt)
    used: set[str] = {row[0] for row in used_result.all()}

    for _ in range(MAX_ATTEMPTS):
        candidate = _random_5digit()
        if candidate not in used:
            return candidate

    raise DiscriminatorExhausted(
        f"닉네임 '{nickname}' 에서 가용 discriminator 를 찾지 못함"
    )
```

- [ ] **Step 4.4: 테스트 통과 확인**

Run:
```bash
docker compose exec backend pytest server/tests/services/test_discriminator_service.py -v
```

Expected: 3 passed.

- [ ] **Step 4.5: 커밋**

```bash
git add server/app/services/discriminator_service.py server/tests/services/test_discriminator_service.py
git commit -m "feat(server): discriminator generation service with collision avoidance"
```

---

## Task 5: auth_service 가입 시 discriminator 발급

**Files:**
- Modify: `server/app/services/auth_service.py`
- Create: `server/tests/services/test_auth_service_discriminator.py`

- [ ] **Step 5.1: 실패하는 테스트 작성**

`server/tests/services/test_auth_service_discriminator.py`:

```python
import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.services.auth_service import login_or_register


@pytest.mark.asyncio
async def test_new_signup_assigns_discriminator(db: AsyncSession):
    user, is_new = await login_or_register(
        db,
        kakao_id=12345,
        nickname="신규유저",
        profile_image_url=None,
    )
    assert is_new is True
    assert user.discriminator is not None
    assert user.discriminator.isdigit()
    assert len(user.discriminator) == 5


@pytest.mark.asyncio
async def test_existing_user_keeps_discriminator(db: AsyncSession):
    # 기존 사용자
    existing = User(
        kakao_id=99999,
        nickname="기존",
        discriminator="42424",
    )
    db.add(existing)
    await db.commit()
    await db.refresh(existing)

    user, is_new = await login_or_register(
        db,
        kakao_id=99999,
        nickname="기존",
        profile_image_url=None,
    )
    assert is_new is False
    assert user.discriminator == "42424"


@pytest.mark.asyncio
async def test_two_users_same_nickname_get_different_discriminators(
    db: AsyncSession,
):
    u1, _ = await login_or_register(db, kakao_id=1, nickname="동명", profile_image_url=None)
    u2, _ = await login_or_register(db, kakao_id=2, nickname="동명", profile_image_url=None)
    assert u1.discriminator != u2.discriminator
```

- [ ] **Step 5.2: 테스트 실패 확인**

Run:
```bash
docker compose exec backend pytest server/tests/services/test_auth_service_discriminator.py -v
```

Expected: FAIL — 신규 사용자 생성 시 discriminator 가 set 되지 않아 NOT NULL 위반 IntegrityError.

- [ ] **Step 5.3: auth_service 에 발급 로직 통합**

`server/app/services/auth_service.py` 의 `login_or_register` 함수를 다음으로 교체 (import 도 추가):

```python
# (파일 상단 import 섹션에 추가)
from app.services.discriminator_service import generate_discriminator

# (login_or_register 함수 교체)
async def login_or_register(
    db: AsyncSession,
    kakao_id: int,
    nickname: str,
    profile_image_url: str | None,
) -> tuple[User, bool]:
    result = await db.execute(select(User).where(User.kakao_id == kakao_id))
    user = result.scalar_one_or_none()
    if user is not None:
        return user, False

    final_nickname = nickname or f"user_{kakao_id}"
    discriminator = await generate_discriminator(db, nickname=final_nickname)

    user = User(
        id=uuid.uuid4(),
        kakao_id=kakao_id,
        nickname=final_nickname,
        discriminator=discriminator,
        profile_image_url=profile_image_url,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user, True
```

- [ ] **Step 5.4: 테스트 통과 확인**

Run:
```bash
docker compose exec backend pytest server/tests/services/test_auth_service_discriminator.py -v
```

Expected: 3 passed.

- [ ] **Step 5.5: 커밋**

```bash
git add server/app/services/auth_service.py server/tests/services/test_auth_service_discriminator.py
git commit -m "feat(server): assign discriminator on signup"
```

---

## Task 6: schemas 에 discriminator 노출

**Files:**
- Modify: `server/app/schemas/user.py`
- Modify: `server/app/schemas/friendship.py`
- Modify: `server/app/routers/me.py`
- Create: `server/tests/routers/test_me_includes_discriminator.py`

- [ ] **Step 6.1: 실패하는 /me 테스트 작성**

`server/tests/routers/test_me_includes_discriminator.py`:

```python
import pytest
from httpx import AsyncClient

from app.models.user import User


@pytest.mark.asyncio
async def test_get_me_includes_discriminator(
    client: AsyncClient, auth_user: User, auth_headers: dict
):
    resp = await client.get("/me", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["nickname"] == auth_user.nickname
    assert data["discriminator"] == auth_user.discriminator
    assert len(data["discriminator"]) == 5
```

> 주: `auth_user` / `auth_headers` 픽스처는 `server/tests/conftest.py` 의 기존 패턴을 따른다. 픽스처 시그니처 확인 후 어긋나면 동일 파일에서 만들어 import.

- [ ] **Step 6.2: 테스트 실패 확인**

Run:
```bash
docker compose exec backend pytest server/tests/routers/test_me_includes_discriminator.py -v
```

Expected: FAIL — `KeyError: 'discriminator'`.

- [ ] **Step 6.3: UserBrief / UserWithIsNew / ProfileUpdateResponse 에 필드 추가**

`server/app/schemas/user.py` 의 클래스들에 `discriminator: str` 필드 추가:

```python
class UserBrief(BaseModel):
    id: uuid.UUID
    nickname: str
    discriminator: str
    profile_image_url: str | None
    background_color: str | None = None
    character: MemberCharacter | None = None

    model_config = {"from_attributes": True}


class UserWithIsNew(BaseModel):
    id: uuid.UUID
    nickname: str | None
    discriminator: str | None
    profile_image_url: str | None
    background_color: str | None = None
    is_new: bool


class AuthLoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    user: UserWithIsNew


class ProfileUpdateResponse(BaseModel):
    id: uuid.UUID
    nickname: str
    discriminator: str
    profile_image_url: str | None
    background_color: str | None = None
```

- [ ] **Step 6.4: /me 라우터에서 discriminator 채워 넣기**

`server/app/routers/me.py` 의 `get_me` 함수에서 `UserBrief` 생성 부분 교체:

```python
    brief = UserBrief(
        id=user.id,
        nickname=user.nickname,
        discriminator=user.discriminator,
        profile_image_url=user.profile_image_url,
        background_color=user.background_color,
    )
```

- [ ] **Step 6.5: AuthLoginResponse 가 사용되는 곳 확인 + 채워넣기**

Run:
```bash
grep -rn "UserWithIsNew(" server/app/
```

각 사용처에서 `discriminator=user.discriminator` 를 추가해 주입한다 (없으면 `discriminator=None` 으로 두어도 schema 가 nullable 이라 통과).

- [ ] **Step 6.6: 테스트 통과 + 회귀 테스트 통과 확인**

Run:
```bash
docker compose exec backend pytest server/tests/routers/test_me_includes_discriminator.py -v
docker compose exec backend pytest -x -q
```

Expected: 새 테스트 PASS, 전체 회귀 PASS.

- [ ] **Step 6.7: 커밋**

```bash
git add server/app/schemas/user.py server/app/routers/me.py server/tests/routers/test_me_includes_discriminator.py
git commit -m "feat(server): expose discriminator on /me and user schemas"
```

---

## Task 7: ContactMatchItem 응답에 discriminator 포함

**Files:**
- Modify: `server/app/schemas/friendship.py`
- Modify: `server/app/services/friend_service.py`
- Create: `server/tests/routers/test_contact_match_includes_discriminator.py`

- [ ] **Step 7.1: 실패하는 테스트 작성**

`server/tests/routers/test_contact_match_includes_discriminator.py`:

```python
import pytest
from httpx import AsyncClient

from app.models.user import User


@pytest.mark.asyncio
async def test_contact_match_includes_discriminator(
    client: AsyncClient, db, auth_headers: dict
):
    target = User(
        kakao_id=77777,
        nickname="매치대상",
        discriminator="33333",
        phone_number="+821012345678",
    )
    db.add(target)
    await db.commit()

    resp = await client.post(
        "/friends/contact-match",
        headers=auth_headers,
        json={"phone_numbers": ["+821012345678"]},
    )
    assert resp.status_code == 200
    matches = resp.json()["data"]["matches"]
    assert len(matches) == 1
    assert matches[0]["nickname"] == "매치대상"
    assert matches[0]["discriminator"] == "33333"
```

- [ ] **Step 7.2: 테스트 실패 확인**

Run:
```bash
docker compose exec backend pytest server/tests/routers/test_contact_match_includes_discriminator.py -v
```

Expected: FAIL — `KeyError: 'discriminator'`.

- [ ] **Step 7.3: ContactMatchItem 스키마 확장**

`server/app/schemas/friendship.py` 의 `ContactMatchItem` 교체:

```python
class ContactMatchItem(BaseModel):
    user_id: uuid.UUID
    nickname: str
    discriminator: str
    profile_image_url: str | None
    friendship_status: str | None  # null, 'pending', 'accepted'
```

- [ ] **Step 7.4: friend_service.match_contacts 에서 discriminator 주입**

`server/app/services/friend_service.py` 의 `match_contacts` 함수 마지막 list comprehension 교체:

```python
    matches = [
        ContactMatchItem(
            user_id=u.id,
            nickname=u.nickname,
            discriminator=u.discriminator,
            profile_image_url=u.profile_image_url,
            friendship_status=status_map.get(u.id),
        )
        for u in matched_users
    ]
```

- [ ] **Step 7.5: 테스트 통과 확인**

Run:
```bash
docker compose exec backend pytest server/tests/routers/test_contact_match_includes_discriminator.py -v
docker compose exec backend pytest -x -q
```

Expected: 새 테스트 PASS, 회귀 PASS.

- [ ] **Step 7.6: 커밋**

```bash
git add server/app/schemas/friendship.py server/app/services/friend_service.py server/tests/routers/test_contact_match_includes_discriminator.py
git commit -m "feat(server): include discriminator in contact-match response"
```

---

## Task 8: friend_service 에 friendship_status 헬퍼 추출

> Task 9 의 `search_by_id` 가 같은 계산을 필요로 하므로 공용화한다. `match_contacts` 의 동일 로직을 함수로 분리하고 호출부를 갱신한다.

**Files:**
- Modify: `server/app/services/friend_service.py`

- [ ] **Step 8.1: 헬퍼 함수 추가**

`server/app/services/friend_service.py` 의 import 섹션 아래에 추가:

```python
async def compute_friendship_status(
    db: AsyncSession,
    *,
    viewer_id: uuid.UUID,
    target_id: uuid.UUID,
) -> str:
    """viewer 가 본 target 의 친구 상태.

    반환: "self" | "accepted" | "pending" | "none"
    """
    if viewer_id == target_id:
        return "self"

    stmt = select(Friendship).where(
        or_(
            (Friendship.requester_id == viewer_id) & (Friendship.addressee_id == target_id),
            (Friendship.addressee_id == viewer_id) & (Friendship.requester_id == target_id),
        )
    )
    result = await db.execute(stmt)
    friendship = result.scalar_one_or_none()
    if friendship is None:
        return "none"
    return friendship.status  # 'pending' | 'accepted'
```

> `match_contacts` 의 status_map 로직은 N개 ID 한 방 조회라 효율이 다르므로 그대로 유지한다 (헬퍼는 단일 조회 케이스 전용).

- [ ] **Step 8.2: 회귀 테스트 통과 확인**

Run:
```bash
docker compose exec backend pytest -x -q
```

Expected: 모든 기존 테스트 PASS.

- [ ] **Step 8.3: 커밋**

```bash
git add server/app/services/friend_service.py
git commit -m "feat(server): add compute_friendship_status helper"
```

---

## Task 9: POST /users/search-by-id 엔드포인트

**Files:**
- Create: `server/app/schemas/user_search.py`
- Create: `server/app/services/user_search_service.py`
- Modify: `server/app/routers/users.py`
- Create: `server/tests/routers/test_users_search_by_id.py`

- [ ] **Step 9.1: 실패하는 라우터 테스트 작성**

`server/tests/routers/test_users_search_by_id.py`:

```python
import pytest
from httpx import AsyncClient

from app.models.friendship import Friendship
from app.models.user import User


@pytest.mark.asyncio
async def test_search_by_id_returns_user(
    client: AsyncClient, db, auth_headers: dict, auth_user: User
):
    target = User(kakao_id=10, nickname="대상", discriminator="55555")
    db.add(target)
    await db.commit()
    await db.refresh(target)

    resp = await client.post(
        "/users/search-by-id",
        headers=auth_headers,
        json={"nickname": "대상", "discriminator": "55555"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["user_id"] == str(target.id)
    assert data["nickname"] == "대상"
    assert data["discriminator"] == "55555"
    assert data["friendship_status"] == "none"


@pytest.mark.asyncio
async def test_search_by_id_self_returns_self_status(
    client: AsyncClient, auth_headers: dict, auth_user: User
):
    resp = await client.post(
        "/users/search-by-id",
        headers=auth_headers,
        json={
            "nickname": auth_user.nickname,
            "discriminator": auth_user.discriminator,
        },
    )
    assert resp.status_code == 200
    assert resp.json()["data"]["friendship_status"] == "self"


@pytest.mark.asyncio
async def test_search_by_id_accepted_friend(
    client: AsyncClient, db, auth_headers: dict, auth_user: User
):
    friend = User(kakao_id=20, nickname="친구", discriminator="22222")
    db.add(friend)
    await db.flush()
    db.add(
        Friendship(
            requester_id=auth_user.id,
            addressee_id=friend.id,
            status="accepted",
        )
    )
    await db.commit()

    resp = await client.post(
        "/users/search-by-id",
        headers=auth_headers,
        json={"nickname": "친구", "discriminator": "22222"},
    )
    assert resp.json()["data"]["friendship_status"] == "accepted"


@pytest.mark.asyncio
async def test_search_by_id_pending_friend(
    client: AsyncClient, db, auth_headers: dict, auth_user: User
):
    other = User(kakao_id=30, nickname="요청", discriminator="11111")
    db.add(other)
    await db.flush()
    db.add(
        Friendship(
            requester_id=auth_user.id,
            addressee_id=other.id,
            status="pending",
        )
    )
    await db.commit()

    resp = await client.post(
        "/users/search-by-id",
        headers=auth_headers,
        json={"nickname": "요청", "discriminator": "11111"},
    )
    assert resp.json()["data"]["friendship_status"] == "pending"


@pytest.mark.asyncio
async def test_search_by_id_not_found(
    client: AsyncClient, auth_headers: dict
):
    resp = await client.post(
        "/users/search-by-id",
        headers=auth_headers,
        json={"nickname": "없는유저", "discriminator": "99999"},
    )
    assert resp.status_code == 404
    assert resp.json()["error"]["code"] == "USER_NOT_FOUND"


@pytest.mark.asyncio
async def test_search_by_id_invalid_format(
    client: AsyncClient, auth_headers: dict
):
    resp = await client.post(
        "/users/search-by-id",
        headers=auth_headers,
        json={"nickname": "x", "discriminator": "ABC"},  # 숫자 아님
    )
    assert resp.status_code in (400, 422)
    if resp.status_code == 400:
        assert resp.json()["error"]["code"] == "INVALID_ID_FORMAT"


@pytest.mark.asyncio
async def test_search_by_id_requires_auth(client: AsyncClient):
    resp = await client.post(
        "/users/search-by-id",
        json={"nickname": "x", "discriminator": "12345"},
    )
    assert resp.status_code == 401
```

- [ ] **Step 9.2: 테스트 실패 확인**

Run:
```bash
docker compose exec backend pytest server/tests/routers/test_users_search_by_id.py -v
```

Expected: FAIL — 라우트 미존재 (404 모두).

- [ ] **Step 9.3: 요청 / 응답 스키마 작성**

`server/app/schemas/user_search.py`:

```python
import uuid

from pydantic import BaseModel, Field


class UserSearchByIdRequest(BaseModel):
    nickname: str = Field(min_length=1, max_length=30)
    discriminator: str = Field(pattern=r"^[0-9]{5}$")


class UserSearchByIdResponse(BaseModel):
    user_id: uuid.UUID
    nickname: str
    discriminator: str
    profile_image_url: str | None
    friendship_status: str  # "none" | "pending" | "accepted" | "self"
```

- [ ] **Step 9.4: 비즈니스 로직 작성**

`server/app/services/user_search_service.py`:

```python
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.exceptions import AppException
from app.models.user import User
from app.schemas.user_search import UserSearchByIdResponse
from app.services.friend_service import compute_friendship_status


async def search_by_id(
    db: AsyncSession,
    *,
    viewer_id: uuid.UUID,
    nickname: str,
    discriminator: str,
) -> UserSearchByIdResponse:
    stmt = select(User).where(
        User.nickname == nickname,
        User.discriminator == discriminator,
    )
    result = await db.execute(stmt)
    target = result.scalar_one_or_none()
    if target is None:
        raise AppException(
            status_code=404,
            code="USER_NOT_FOUND",
            message="해당 ID 를 가진 사용자를 찾을 수 없어요.",
        )

    status = await compute_friendship_status(
        db, viewer_id=viewer_id, target_id=target.id
    )

    return UserSearchByIdResponse(
        user_id=target.id,
        nickname=target.nickname,
        discriminator=target.discriminator,
        profile_image_url=target.profile_image_url,
        friendship_status=status,
    )
```

- [ ] **Step 9.5: 라우터 등록**

`server/app/routers/users.py` 에 다음 추가 (파일 상단 import + 함수):

```python
# 상단 import 섹션에 추가
from app.schemas.user_search import UserSearchByIdRequest, UserSearchByIdResponse
from app.services import user_search_service


# 라우터에 함수 추가
@router.post("/search-by-id")
async def search_user_by_id(
    body: UserSearchByIdRequest,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await user_search_service.search_by_id(
        db,
        viewer_id=user_id,
        nickname=body.nickname,
        discriminator=body.discriminator,
    )
    return {"data": result.model_dump(mode="json")}
```

> `mode="json"` 은 UUID 를 문자열로 직렬화하기 위함. 기존 라우터 패턴 확인 후 다른 곳도 같은 방식이면 그대로, `model_dump()` 로 충분하면 그대로 사용.

- [ ] **Step 9.6: 테스트 통과 확인**

Run:
```bash
docker compose exec backend pytest server/tests/routers/test_users_search_by_id.py -v
docker compose exec backend pytest -x -q
```

Expected: 7 passed (또는 6 + invalid_format 422 분기), 회귀 PASS.

- [ ] **Step 9.7: 백엔드 빌드 검증 (rule: local-build-verification)**

Run:
```bash
docker compose up --build -d backend
sleep 2
curl -fsS http://localhost:8000/health
```

Expected: `{"status":"ok"}` 또는 동등.

- [ ] **Step 9.8: 커밋**

```bash
git add server/app/schemas/user_search.py server/app/services/user_search_service.py server/app/routers/users.py server/tests/routers/test_users_search_by_id.py
git commit -m "feat(server): POST /users/search-by-id endpoint"
```

---

## Task 10: 프론트 — AuthUser 에 discriminator 추가

**Files:**
- Modify: `app/lib/features/auth/providers/auth_provider.dart`

- [ ] **Step 10.1: AuthUser 클래스 + /me 파싱 갱신**

`app/lib/features/auth/providers/auth_provider.dart` 의 `AuthUser` 클래스 정의 부분 (현재 단순 dataclass) 에 `discriminator` 필드 추가. 파일 위쪽 클래스 선언과 `/me` 파싱부 두 곳을 수정.

(a) `AuthUser` 정의에 필드 추가:

```dart
class AuthUser {
  final String id;
  final String? nickname;
  final String? discriminator;
  final String? profileImageUrl;
  final String? backgroundColor;
  final bool isNew;

  AuthUser({
    required this.id,
    this.nickname,
    this.discriminator,
    this.profileImageUrl,
    this.backgroundColor,
    this.isNew = false,
  });
}
```

(b) `/me` 파싱부 (이미 확인된 33–43 행 부근) 의 `AuthUser(...)` 생성에 `discriminator: map['discriminator'] as String?` 추가.

(c) 로그인 응답에서 `AuthUser` 를 만드는 곳도 찾아 동일하게 추가:

```bash
grep -n "AuthUser(" app/lib/features/auth/
```

각 위치에서 `discriminator: ...` 를 적절히 채운다.

- [ ] **Step 10.2: 분석 통과 확인**

Run:
```bash
cd app && flutter analyze lib/features/auth/
```

Expected: `No issues found!`.

- [ ] **Step 10.3: 커밋**

```bash
git add app/lib/features/auth/providers/auth_provider.dart
git commit -m "feat(app): add discriminator to AuthUser"
```

---

## Task 11: 프론트 — ContactMatchItem 에 discriminator 추가

**Files:**
- Modify: `app/lib/features/friends/models/friend_data.dart`

- [ ] **Step 11.1: freezed 모델 갱신**

`app/lib/features/friends/models/friend_data.dart` 의 `ContactMatchItem` 클래스를 다음으로 교체:

```dart
@freezed
class ContactMatchItem with _$ContactMatchItem {
  const factory ContactMatchItem({
    @JsonKey(name: 'user_id') required String userId,
    required String nickname,
    required String discriminator,
    @JsonKey(name: 'profile_image_url') String? profileImageUrl,
    @JsonKey(name: 'friendship_status') String? friendshipStatus,
  }) = _ContactMatchItem;

  factory ContactMatchItem.fromJson(Map<String, dynamic> json) =>
      _$ContactMatchItemFromJson(json);
}
```

- [ ] **Step 11.2: build_runner 재생성**

Run:
```bash
cd app && dart run build_runner build --delete-conflicting-outputs
```

Expected: `Succeeded` 메시지.

- [ ] **Step 11.3: 분석 통과 확인**

Run:
```bash
cd app && flutter analyze lib/features/friends/
```

Expected: `No issues found!` (다른 곳에서 ContactMatchItem 생성하는 코드 있다면 추가 인자 필요 → 동일 단계에서 fix).

- [ ] **Step 11.4: 커밋**

```bash
git add app/lib/features/friends/models/friend_data.dart app/lib/features/friends/models/friend_data.freezed.dart app/lib/features/friends/models/friend_data.g.dart
git commit -m "feat(app): add discriminator to ContactMatchItem"
```

---

## Task 12: 프론트 — ID 포맷 유틸 + 테스트

**Files:**
- Create: `app/lib/features/friends/utils/user_id_format.dart`
- Create: `app/test/features/friends/utils/user_id_format_test.dart`

- [ ] **Step 12.1: 실패하는 단위 테스트 작성**

`app/test/features/friends/utils/user_id_format_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:haeda/features/friends/utils/user_id_format.dart';

void main() {
  group('parseUserId', () {
    test('returns nickname and discriminator on valid input', () {
      final result = parseUserId('홍길동#43217');
      expect(result, isNotNull);
      expect(result!.nickname, '홍길동');
      expect(result.discriminator, '43217');
    });

    test('returns null when missing #', () {
      expect(parseUserId('홍길동43217'), isNull);
    });

    test('returns null when discriminator is not 5 digits', () {
      expect(parseUserId('홍길동#1234'), isNull);
      expect(parseUserId('홍길동#123456'), isNull);
      expect(parseUserId('홍길동#abcde'), isNull);
    });

    test('returns null when nickname is empty', () {
      expect(parseUserId('#43217'), isNull);
    });

    test('returns null when nickname is too long', () {
      final long = 'a' * 31;
      expect(parseUserId('$long#12345'), isNull);
    });

    test('handles leading/trailing whitespace', () {
      final result = parseUserId('  홍길동#43217  ');
      expect(result, isNotNull);
      expect(result!.nickname, '홍길동');
    });
  });

  group('formatUserId', () {
    test('joins with #', () {
      expect(formatUserId('홍길동', '43217'), '홍길동#43217');
    });
  });
}
```

> `haeda` 는 pubspec.yaml 의 패키지명. 다르면 import 경로 보정.

- [ ] **Step 12.2: 테스트 실패 확인**

Run:
```bash
cd app && flutter test test/features/friends/utils/user_id_format_test.dart
```

Expected: FAIL — `Target of URI doesn't exist`.

- [ ] **Step 12.3: 유틸 구현**

`app/lib/features/friends/utils/user_id_format.dart`:

```dart
class ParsedUserId {
  final String nickname;
  final String discriminator;

  const ParsedUserId({required this.nickname, required this.discriminator});
}

final RegExp _userIdPattern = RegExp(r'^(.{1,30})#([0-9]{5})$');

ParsedUserId? parseUserId(String input) {
  final trimmed = input.trim();
  final match = _userIdPattern.firstMatch(trimmed);
  if (match == null) return null;
  return ParsedUserId(
    nickname: match.group(1)!,
    discriminator: match.group(2)!,
  );
}

String formatUserId(String nickname, String discriminator) {
  return '$nickname#$discriminator';
}
```

- [ ] **Step 12.4: 테스트 통과 확인**

Run:
```bash
cd app && flutter test test/features/friends/utils/user_id_format_test.dart
```

Expected: All tests passed.

- [ ] **Step 12.5: 커밋**

```bash
git add app/lib/features/friends/utils/user_id_format.dart app/test/features/friends/utils/user_id_format_test.dart
git commit -m "feat(app): add user ID parse/format utilities"
```

---

## Task 13: 프론트 — ContactSearchScreen 에 ID 검색 블록 추가

**Files:**
- Modify: `app/lib/features/friends/screens/contact_search_screen.dart`
- Create: `app/test/features/friends/screens/contact_search_screen_id_test.dart`

- [ ] **Step 13.1: 위젯 테스트 작성 (실패)**

`app/test/features/friends/screens/contact_search_screen_id_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haeda/features/friends/screens/contact_search_screen.dart';

void main() {
  testWidgets('shows ID search field with placeholder', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ContactSearchScreen()),
      ),
    );
    expect(find.text('닉네임#12345 형식으로 입력'), findsOneWidget);
  });

  testWidgets('ID search button stays disabled for invalid input',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ContactSearchScreen()),
      ),
    );
    await tester.enterText(find.byKey(const Key('id_search_field')), '홍길동');
    await tester.pump();
    final button = tester.widget<IconButton>(
      find.byKey(const Key('id_search_button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('ID search button enables for valid format', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ContactSearchScreen()),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('id_search_field')),
      '홍길동#43217',
    );
    await tester.pump();
    final button = tester.widget<IconButton>(
      find.byKey(const Key('id_search_button')),
    );
    expect(button.onPressed, isNotNull);
  });
}
```

- [ ] **Step 13.2: 테스트 실패 확인**

Run:
```bash
cd app && flutter test test/features/friends/screens/contact_search_screen_id_test.dart
```

Expected: FAIL — 위젯에 해당 Key 없음.

- [ ] **Step 13.3: 화면에 ID 입력 블록 + 검색 로직 추가**

`app/lib/features/friends/screens/contact_search_screen.dart` 를 다음 변경:

(a) 상단 import 에 추가:

```dart
import '../utils/user_id_format.dart';
```

(b) State 클래스에 필드 추가 (`_phoneController` 옆):

```dart
final _idController = TextEditingController();
bool _idSearchLoading = false;
ParsedUserId? _parsedId;
```

(c) `dispose` 에 `_idController.dispose();` 추가.

(d) `_idController` 의 텍스트 변화로 파싱하는 핸들러를 `initState` 에서 등록:

```dart
@override
void initState() {
  super.initState();
  _idController.addListener(() {
    setState(() {
      _parsedId = parseUserId(_idController.text);
    });
  });
}
```

(e) ID 검색 메서드 추가:

```dart
Future<void> _searchById() async {
  final parsed = _parsedId;
  if (parsed == null) return;

  setState(() {
    _idSearchLoading = true;
    _error = null;
  });

  try {
    final dio = ref.read(dioProvider);
    final response = await dio.post(
      '/users/search-by-id',
      data: {
        'nickname': parsed.nickname,
        'discriminator': parsed.discriminator,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final match = ContactMatchItem(
      userId: data['user_id'] as String,
      nickname: data['nickname'] as String,
      discriminator: data['discriminator'] as String,
      profileImageUrl: data['profile_image_url'] as String?,
      friendshipStatus: data['friendship_status'] as String?,
    );
    setState(() {
      _matches = [match];
      _idSearchLoading = false;
    });
  } on DioException catch (e) {
    setState(() {
      _idSearchLoading = false;
      if (e.response?.statusCode == 404) {
        _matches = [];
        _error = null;
      } else {
        _error = '검색 중 오류가 발생했어요.';
      }
    });
  } catch (_) {
    setState(() {
      _idSearchLoading = false;
      _error = '검색 중 오류가 발생했어요.';
    });
  }
}
```

> `DioException` import: `import 'package:dio/dio.dart';` (없으면 추가)

(f) build 메서드의 "전화번호 입력" 블록 바로 아래에 ID 입력 블록 삽입:

```dart
// ID(닉네임#숫자) 직접 입력
Padding(
  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
  child: TextField(
    key: const Key('id_search_field'),
    controller: _idController,
    decoration: InputDecoration(
      hintText: '닉네임#12345 형식으로 입력',
      prefixIcon: const Icon(Icons.alternate_email),
      suffixIcon: IconButton(
        key: const Key('id_search_button'),
        onPressed: (_idSearchLoading || _parsedId == null)
            ? null
            : _searchById,
        icon: _idSearchLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.search),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
    ),
    onSubmitted: (_) {
      if (_parsedId != null) _searchById();
    },
  ),
),
```

(g) `_buildMatchTile` 의 trailing 분기 수정 — `friendshipStatus == 'self'` 케이스 추가:

```dart
Widget _buildMatchTile(ContactMatchItem match, ThemeData theme) {
  final alreadyFriend = match.friendshipStatus == 'accepted';
  final isSelf = match.friendshipStatus == 'self';
  final pending = match.friendshipStatus == 'pending' ||
      _sentRequests.contains(match.userId);

  return ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    leading: CircleAvatar(
      backgroundColor: theme.colorScheme.primary.withAlpha(51),
      backgroundImage: match.profileImageUrl != null
          ? NetworkImage(match.profileImageUrl!)
          : null,
      child: match.profileImageUrl == null
          ? Text(
              match.nickname.isNotEmpty ? match.nickname[0] : '?',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    ),
    title: Text('${match.nickname}#${match.discriminator}'),
    trailing: isSelf
        ? const Chip(label: Text('본인'))
        : alreadyFriend
            ? Chip(
                label: const Text('친구'),
                backgroundColor: theme.colorScheme.primaryContainer,
              )
            : pending
                ? const Chip(label: Text('요청됨'))
                : FilledButton.tonal(
                    onPressed: () => _sendRequest(match.userId),
                    child: const Text('친구 요청'),
                  ),
  );
}
```

- [ ] **Step 13.4: 테스트 통과 확인**

Run:
```bash
cd app && flutter test test/features/friends/screens/contact_search_screen_id_test.dart
```

Expected: 3 tests passed.

- [ ] **Step 13.5: 분석 통과**

Run:
```bash
cd app && flutter analyze lib/features/friends/
```

Expected: `No issues found!`.

- [ ] **Step 13.6: 커밋**

```bash
git add app/lib/features/friends/screens/contact_search_screen.dart app/test/features/friends/screens/contact_search_screen_id_test.dart
git commit -m "feat(app): add ID(닉네임#숫자) search field to contact search screen"
```

---

## Task 14: 프론트 — Settings 화면 "내 ID" 표시

**Files:**
- Modify: `app/lib/features/settings/screens/settings_screen.dart`
- Create: `app/test/features/settings/screens/settings_my_id_test.dart`

- [ ] **Step 14.1: 위젯 테스트 작성 (실패)**

`app/test/features/settings/screens/settings_my_id_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haeda/features/auth/providers/auth_provider.dart';
import 'package:haeda/features/settings/screens/settings_screen.dart';

void main() {
  testWidgets('내 ID 행이 표시되고 탭 시 클립보드에 복사된다', (tester) async {
    final messages = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      messages.add(call);
      return null;
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            () => _FakeAuthNotifier(
              AuthUser(
                id: 'u1',
                nickname: '테스트',
                discriminator: '12345',
                isNew: false,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    expect(find.text('테스트#12345'), findsOneWidget);

    await tester.tap(find.byKey(const Key('my_id_row')));
    await tester.pump();

    final copyCall = messages.firstWhere((c) => c.method == 'Clipboard.setData');
    expect(copyCall.arguments['text'], '테스트#12345');
  });
}

// 최소 테스트용 fake notifier — 실제 구조 따라 보정 필요
class _FakeAuthNotifier extends AuthState {
  final AuthUser? user;
  _FakeAuthNotifier(this.user);

  @override
  AsyncValue<AuthUser?> build() => AsyncData(user);
}
```

> `AuthState` 의 정확한 시그니처는 `auth_provider.dart` 의 코드젠 결과에 맞춰 보정. 만약 fake 작성이 너무 무거우면 `ProviderScope` overrides 로 우회 (직접 Stream/Future provider override).

- [ ] **Step 14.2: 테스트 실패 확인**

Run:
```bash
cd app && flutter test test/features/settings/screens/settings_my_id_test.dart
```

Expected: FAIL — `my_id_row` Key 없음.

- [ ] **Step 14.3: SettingsScreen 에 "내 ID" 섹션 추가**

`app/lib/features/settings/screens/settings_screen.dart` 변경:

(a) 상단 import 에 추가:

```dart
import 'package:flutter/services.dart';
```

(b) `_logout` 옆에 메서드 추가:

```dart
Future<void> _copyMyId(String fullId) async {
  await Clipboard.setData(ClipboardData(text: fullId));
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('ID 복사됨')),
  );
}
```

(c) build 메서드의 Profile section (현재 76–106 행) 바로 아래에 "내 ID" 섹션 삽입:

```dart
// ── 내 ID 섹션 ──
if (user?.nickname != null && user?.discriminator != null) ...[
  Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
    child: Text(
      '내 ID',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  ),
  ListTile(
    key: const Key('my_id_row'),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    title: Text(
      '${user!.nickname}#${user.discriminator}',
      style: const TextStyle(fontFamily: 'monospace'),
    ),
    subtitle: const Text('탭하면 복사돼요'),
    trailing: const Icon(Icons.copy, size: 18),
    onTap: () => _copyMyId('${user.nickname}#${user.discriminator}'),
  ),
],
```

- [ ] **Step 14.4: 테스트 통과 확인**

Run:
```bash
cd app && flutter test test/features/settings/screens/settings_my_id_test.dart
```

Expected: 1 test passed.

만약 fake notifier 가 호환 안 되면, 다음 대안을 사용 — `ProviderScope.overrides` 에서 단순 `AsyncData(AuthUser(...))` 를 반환하도록 override 한 구조로 작성:

```dart
ProviderScope(
  overrides: [
    authStateProvider.overrideWith(
      (ref) async => AuthUser(...)),
  ],
  ...
)
```

(정확한 override API 는 `auth_provider.dart` 의 declaration 에 맞춤.)

- [ ] **Step 14.5: 커밋**

```bash
git add app/lib/features/settings/screens/settings_screen.dart app/test/features/settings/screens/settings_my_id_test.dart
git commit -m "feat(app): show my ID in settings with tap-to-copy"
```

---

## Task 15: 프론트 — 마이페이지에 닉네임#숫자 헤더 추가

> `MyPageScreen` 은 현재 닉네임을 표시하지 않으므로, 챌린지 리스트 위에 작은 프로필 헤더를 추가한다 (탭하면 복사).

**Files:**
- Modify: `app/lib/features/my_page/screens/my_page_screen.dart`

- [ ] **Step 15.1: 헤더 추가**

`app/lib/features/my_page/screens/my_page_screen.dart` 의 `_ChallengeList` 위에 `_MyIdHeader` 위젯 추가하고 ListView 첫 자식으로 삽입.

(a) 상단 import 추가:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
```

(b) 파일 하단에 위젯 추가:

```dart
class _MyIdHeader extends ConsumerWidget {
  const _MyIdHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null ||
        user.nickname == null ||
        user.discriminator == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final fullId = '${user.nickname}#${user.discriminator}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: GestureDetector(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: fullId));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ID 복사됨')),
          );
        },
        child: Row(
          children: [
            Text(
              user.nickname!,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '#${user.discriminator}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.copy,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
```

(c) `_ChallengeList.build` 의 ListView children 맨 앞에 `const _MyIdHeader(),` 삽입.

- [ ] **Step 15.2: 분석 통과**

Run:
```bash
cd app && flutter analyze lib/features/my_page/
```

Expected: `No issues found!`.

- [ ] **Step 15.3: 커밋**

```bash
git add app/lib/features/my_page/screens/my_page_screen.dart
git commit -m "feat(app): show nickname#discriminator header on my page"
```

---

## Task 16: iOS simulator clean install + 수동 검증 (rule: ios-simulator)

**Files:** none — 빌드 / 실행만.

- [ ] **Step 16.1: simulator clean install (haeda-ios-deploy 스킬 절차)**

Run:
```bash
DEVICE_ID=$(xcrun simctl list devices booted | grep "Booted" | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
BUNDLE_ID=$(grep -m1 "PRODUCT_BUNDLE_IDENTIFIER" app/ios/Runner.xcodeproj/project.pbxproj | sed -E 's/.*= ([^;]+);.*/\1/' | tr -d '"')

xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl uninstall "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true

cd app && flutter clean && flutter pub get && flutter build ios --simulator && cd ..

xcrun simctl install "$DEVICE_ID" app/build/ios/iphonesimulator/Runner.app
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"
```

Expected: 빌드 성공 + 앱 실행. 빌드 실패 시 STOP.

- [ ] **Step 16.2: 수동 시나리오 검증 (사용자 확인 항목)**

iOS simulator 에서 다음을 확인:

1. 로그인 → 설정 화면 진입 → 프로필 카드 아래에 "내 ID" 섹션 + `닉네임#xxxxx` 표시
2. "내 ID" 행 탭 → 토스트 "ID 복사됨"
3. 마이페이지 진입 → 상단에 `닉네임#xxxxx` 헤더 + 복사 아이콘 → 탭 시 토스트 "ID 복사됨"
4. 친구 찾기 화면 진입 → "닉네임#12345 형식으로 입력" placeholder 가진 새 입력란 보임
5. 잘못된 형식 입력 (`abc`) → 검색 버튼 비활성
6. 본인 ID 입력 → 결과 카드에 "본인" 칩 표시 (요청 버튼 없음)
7. 다른 유효한 ID 입력 (테스트 계정 2개 미리 가입 필요) → 결과 카드 + "친구 요청" 버튼 → 클릭 시 토스트 "친구 요청을 보냈어요!"
8. 존재하지 않는 ID (`없는유저#99999`) → "검색 결과가 없어요." 표시

스크린샷은 `docs/reports/screenshots/2026-04-26-feature-friend-id-search-{NN}.png` 로 저장 (보고서 단계에서 사용).

---

## Task 17: 보고서 작성 + 머지

**Files:**
- Create: `docs/reports/2026-04-26-feature-friend-id-search.md`

- [ ] **Step 17.1: 작업 보고서 작성**

`docs/reports/2026-04-26-feature-friend-id-search.md` 신규 작성. 섹션 (Date, Worktree, Role, Request, Root cause, Actions, Verification, Follow-ups, Related). Verification 섹션에 다음을 인용 포함:

- `pytest -x -q` 결과 (passed 수)
- `flutter test` 결과 (passed 수)
- `curl /health` 응답
- iOS simulator 시나리오 8개 항목 PASS / 스크린샷 경로

- [ ] **Step 17.2: 보고서 커밋**

```bash
git add docs/reports/2026-04-26-feature-friend-id-search.md
git commit -m "docs(report): friend ID 검색·추가 기능 작업 보고서"
```

- [ ] **Step 17.3: PR 머지 (commit 스킬)**

`/commit` 스킬을 호출해 PR 생성 + 자동 머지. 실패 시 STOP, 사용자에게 보고.

---

## Self-Review

- 모든 spec 섹션이 task 로 매핑됨 (§3 schema → Task 2/3, §4 migration → Task 3, §5 generation → Task 4/5, §6 endpoint → Task 9, §7 screen → Task 13, §8 settings/my_page → Task 14/15, §9 model sync → Task 6/7/10/11, §10 edge cases → Task 9 테스트 + Task 13 self 분기, §11 tests → 각 task 의 test step, §13 out-of-scope → 본 plan 에서 제외 명시).
- 모든 단계는 정확한 파일 경로 + 실제 코드 + 실제 명령 + 기대 출력을 포함.
- TDD: 모든 코드 변경은 RED → GREEN → COMMIT 사이클.
- 큰 함수 / 큰 파일 회피: `discriminator_service`, `user_search_service`, `user_id_format` 모두 단일 책임 신규 파일.
- 의존성 순서: 문서(1) → 모델(2) → 마이그레이션(3) → 발급 서비스(4) → auth 통합(5) → 응답 schema(6/7) → 헬퍼(8) → 엔드포인트(9) → 프론트 모델(10/11) → 프론트 유틸(12) → 화면 통합(13/14/15) → 검증(16) → 보고/머지(17).
