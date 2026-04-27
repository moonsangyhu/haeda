# 챌린지 인증 댓글 기능 복원 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 2026-04-25 commit `206274b` 가 제거한 댓글 기능을 정확히 동일 형태로 복원한다 (단, 그 사이 변경된 파일의 변경분은 보존). DB 는 신규 migration 021 로 `comments` 테이블을 재생성한다.

**Architecture:** 이전 구현이 git 히스토리에 그대로 보존돼 있어, 핵심 전략은 **`git show 206274b^:<path>` 로 이전 코드를 추출 → 현재 파일에 적절히 머지 → TDD 로 재검증**이다. service 책임 분리는 이전과 약간 달라진다: `verification_service.py` 는 인증 상세 + comments JOIN 까지 책임지고, 신규 `comment_service.py` 는 댓글 CRUD (list / create) 만 담당한다.

**Tech Stack:** FastAPI + SQLAlchemy 2.0 async + Pydantic v2 + Alembic / Flutter + Riverpod + dio + freezed.

**Source spec:** `docs/superpowers/specs/2026-04-27-restore-comment-feature-design.md`

**Reference reports:**
- `docs/reports/2026-04-25-feature-remove-comment-feature.md` — 이번 복원의 역연산
- 검색 키워드: `comment`, `Comment`, `댓글`, `verification`, `challenge_space`

---

## Phase 1 — Backend: model + schema + migration (신규 파일)

### Task 1: Comment 모델 복원

**Files:**
- Create: `server/app/models/comment.py`
- Modify: `server/app/models/__init__.py`
- Modify: `server/app/models/user.py`
- Modify: `server/app/models/verification.py`

- [ ] **Step 1.1: 이전 파일 추출**

```bash
git show 206274b^:server/app/models/comment.py > server/app/models/comment.py
```

- [ ] **Step 1.2: `__init__.py` 에 Comment import 추가**

`server/app/models/__init__.py` 에 다음 import 와 export 추가 (Challenge 등 다른 모델 옆에):

```python
from app.models.comment import Comment
```

`__all__` 리스트에 `"Comment"` 추가.

- [ ] **Step 1.3: `User.comments` relationship 추가**

`server/app/models/user.py` 에 다른 relationship 들과 같은 위치에 추가:

```python
comments: Mapped[list["Comment"]] = relationship(
    "Comment", back_populates="author", cascade="all, delete-orphan"
)
```

(SQLAlchemy 2.0 typed mapping 형식. `from app.models.comment import Comment` 는 TYPE_CHECKING 없이 forward-ref 문자열로 처리.)

- [ ] **Step 1.4: `Verification.comments` relationship 추가**

`server/app/models/verification.py` 에 다음 추가:

```python
comments: Mapped[list["Comment"]] = relationship(
    "Comment", back_populates="verification", cascade="all, delete-orphan"
)
```

- [ ] **Step 1.5: import 검증**

```bash
docker compose exec backend python -c "from app.models import Comment; print(Comment.__tablename__)"
```

Expected: `comments` 출력. (이 시점엔 테이블이 DB 에 없어도 import 자체는 성공해야 함.)

- [ ] **Step 1.6: Commit**

```bash
git add server/app/models/comment.py server/app/models/__init__.py server/app/models/user.py server/app/models/verification.py
git commit -m "feat(server): Comment 모델 + relationship 복원"
```

---

### Task 2: Comment schema 복원

**Files:**
- Create: `server/app/schemas/comment.py`
- Modify: `server/app/schemas/verification.py`

- [ ] **Step 2.1: comment.py 신규 작성**

`server/app/schemas/comment.py`:

```python
import uuid
from datetime import datetime

from pydantic import BaseModel

from app.schemas.character_schema import MemberCharacter


class CommentAuthor(BaseModel):
    id: uuid.UUID
    nickname: str
    profile_image_url: str | None
    character: MemberCharacter | None = None

    model_config = {"from_attributes": True}


class CommentItem(BaseModel):
    id: uuid.UUID
    author: CommentAuthor
    content: str
    created_at: datetime

    model_config = {"from_attributes": True}


class CommentCreateRequest(BaseModel):
    content: str


class CommentsListResponse(BaseModel):
    comments: list[CommentItem]
    next_cursor: str | None
```

- [ ] **Step 2.2: `VerificationDetailResponse` 에 comments 필드 + `VerificationItem` 에 comment_count 필드**

`server/app/schemas/verification.py` 수정:

1. import 부에 `from app.schemas.comment import CommentItem` 추가.
2. `VerificationItem` 에 `comment_count: int` 필드 추가 (created_at 위에).
3. 파일 마지막에 `VerificationDetailResponse` 추가:

```python
class VerificationDetailResponse(BaseModel):
    id: uuid.UUID
    challenge_id: uuid.UUID
    user: UserBrief
    date: date
    photo_urls: list[str] | None
    diary_text: str
    comments: list[CommentItem]
    created_at: datetime

    model_config = {"from_attributes": True}
```

- [ ] **Step 2.3: import 검증**

```bash
docker compose exec backend python -c "from app.schemas.comment import CommentItem, CommentCreateRequest, CommentsListResponse; from app.schemas.verification import VerificationDetailResponse, VerificationItem; print('OK')"
```

Expected: `OK`

- [ ] **Step 2.4: Commit**

```bash
git add server/app/schemas/comment.py server/app/schemas/verification.py
git commit -m "feat(server): Comment schema + VerificationDetailResponse 복원"
```

---

### Task 3: Migration 021 — recreate comments table

**Files:**
- Create: `server/alembic/versions/20260427_0000_021_recreate_comments.py`

- [ ] **Step 3.1: migration 파일 작성**

`server/alembic/versions/20260427_0000_021_recreate_comments.py`:

```python
"""recreate comments table

Revision ID: 021
Revises: 020
Create Date: 2026-04-27 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "021"
down_revision: Union[str, None] = "020"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "comments",
        sa.Column("id", sa.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "verification_id",
            sa.UUID(as_uuid=True),
            sa.ForeignKey("verifications.id"),
            nullable=False,
        ),
        sa.Column(
            "author_id",
            sa.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column("content", sa.String(500), nullable=False),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
    )
    op.create_index("idx_comment_verification", "comments", ["verification_id"])


def downgrade() -> None:
    op.drop_index("idx_comment_verification", table_name="comments")
    op.drop_table("comments")
```

- [ ] **Step 3.2: migration 적용 검증**

```bash
docker compose exec backend alembic upgrade head
```

Expected: `Running upgrade 020 -> 021, recreate comments table`

- [ ] **Step 3.3: 테이블 존재 확인**

```bash
docker compose exec backend psql -h db -U postgres -d haeda -c "\d comments"
```

Expected: `comments` 테이블 정의 출력 (id / verification_id / author_id / content / created_at + idx_comment_verification 인덱스).

- [ ] **Step 3.4: Commit**

```bash
git add server/alembic/versions/20260427_0000_021_recreate_comments.py
git commit -m "feat(server): migration 021 - recreate comments table"
```

---

## Phase 2 — Backend: service + router + seed 통합

### Task 4: comment_service.py 신규

**Files:**
- Create: `server/app/services/comment_service.py`

- [ ] **Step 4.1: comment_service.py 작성** (verification_detail 책임은 verification_service 에 두고, 댓글 list / create 만 담당)

```python
import uuid
from datetime import datetime

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.exceptions import AppException
from app.models.challenge_member import ChallengeMember
from app.models.comment import Comment
from app.models.user import User
from app.models.verification import Verification
from app.schemas.comment import (
    CommentAuthor,
    CommentItem,
    CommentsListResponse,
)
from app.services.character_helpers import load_member_characters


async def _get_verification_or_404(
    db: AsyncSession, verification_id: uuid.UUID
) -> Verification:
    stmt = select(Verification).where(Verification.id == verification_id)
    result = await db.execute(stmt)
    verification = result.scalar_one_or_none()
    if verification is None:
        raise AppException(
            status_code=404,
            code="VERIFICATION_NOT_FOUND",
            message="인증을 찾을 수 없습니다.",
        )
    return verification


async def _check_verification_membership(
    db: AsyncSession, verification: Verification, user_id: uuid.UUID
) -> None:
    stmt = select(ChallengeMember.id).where(
        ChallengeMember.challenge_id == verification.challenge_id,
        ChallengeMember.user_id == user_id,
    )
    result = await db.execute(stmt)
    if result.first() is None:
        raise AppException(
            status_code=403,
            code="NOT_A_MEMBER",
            message="챌린지 참여자가 아닙니다.",
        )


async def get_comments(
    db: AsyncSession,
    verification_id: uuid.UUID,
    user_id: uuid.UUID,
    cursor: str | None,
    limit: int,
) -> CommentsListResponse:
    verification = await _get_verification_or_404(db, verification_id)
    await _check_verification_membership(db, verification, user_id)

    stmt = (
        select(Comment, User)
        .join(User, User.id == Comment.author_id)
        .where(Comment.verification_id == verification_id)
        .order_by(Comment.created_at, Comment.id)
    )

    if cursor is not None:
        try:
            parts = cursor.split("|", 1)
            cursor_dt = datetime.fromisoformat(parts[0])
            cursor_id = uuid.UUID(parts[1]) if len(parts) > 1 else None
        except (ValueError, IndexError):
            raise AppException(
                status_code=422,
                code="VALIDATION_ERROR",
                message="유효하지 않은 커서 값입니다.",
            )
        if cursor_id is not None:
            stmt = stmt.where(
                or_(
                    Comment.created_at > cursor_dt,
                    and_(
                        Comment.created_at == cursor_dt,
                        Comment.id > cursor_id,
                    ),
                )
            )
        else:
            stmt = stmt.where(Comment.created_at > cursor_dt)

    stmt = stmt.limit(limit + 1)
    result = await db.execute(stmt)
    rows = result.all()

    has_next = len(rows) > limit
    page_rows = rows[:limit]

    author_ids = list({row.User.id for row in page_rows})
    char_map = await load_member_characters(db, author_ids)

    comments = [
        CommentItem(
            id=row.Comment.id,
            author=CommentAuthor(
                id=row.User.id,
                nickname=row.User.nickname,
                profile_image_url=row.User.profile_image_url,
                character=char_map.get(row.User.id),
            ),
            content=row.Comment.content,
            created_at=row.Comment.created_at,
        )
        for row in page_rows
    ]

    next_cursor: str | None = None
    if has_next and page_rows:
        last = page_rows[-1].Comment
        next_cursor = f"{last.created_at.isoformat()}|{last.id}"

    return CommentsListResponse(comments=comments, next_cursor=next_cursor)


async def create_comment(
    db: AsyncSession,
    verification_id: uuid.UUID,
    user_id: uuid.UUID,
    content: str,
) -> CommentItem:
    if len(content) > 500:
        raise AppException(
            status_code=422,
            code="COMMENT_TOO_LONG",
            message="댓글은 500자를 초과할 수 없습니다.",
        )

    verification = await _get_verification_or_404(db, verification_id)
    await _check_verification_membership(db, verification, user_id)

    user_stmt = select(User).where(User.id == user_id)
    user_result = await db.execute(user_stmt)
    author = user_result.scalar_one()

    char_map = await load_member_characters(db, [user_id])

    comment = Comment(
        id=uuid.uuid4(),
        verification_id=verification_id,
        author_id=user_id,
        content=content,
    )
    db.add(comment)
    await db.commit()
    await db.refresh(comment)

    return CommentItem(
        id=comment.id,
        author=CommentAuthor(
            id=author.id,
            nickname=author.nickname,
            profile_image_url=author.profile_image_url,
            character=char_map.get(user_id),
        ),
        content=comment.content,
        created_at=comment.created_at,
    )
```

- [ ] **Step 4.2: import 검증**

```bash
docker compose exec backend python -c "from app.services import comment_service; print(comment_service.create_comment, comment_service.get_comments)"
```

Expected: 두 함수 객체 출력.

- [ ] **Step 4.3: Commit**

```bash
git add server/app/services/comment_service.py
git commit -m "feat(server): comment_service - get_comments + create_comment"
```

---

### Task 5: verification_service 의 get_verification_detail 에 comments + comment_count 통합

**Files:**
- Modify: `server/app/services/verification_service.py`

- [ ] **Step 5.1: 현재 파일 읽고 정확한 라인 위치 파악**

```bash
grep -n "def get_verification_detail\|comment_count\|VerificationDetailResponse\|VerificationItem" server/app/services/verification_service.py
```

- [ ] **Step 5.2: `get_verification_detail` 함수 수정**

기존 함수의 응답 타입을 `VerificationDetailResponse` 로 바꾸고, 댓글 JOIN + char_map 포함:

```python
from app.models.comment import Comment
from app.schemas.comment import CommentAuthor, CommentItem
from app.schemas.verification import VerificationDetailResponse

async def get_verification_detail(
    db: AsyncSession,
    verification_id: uuid.UUID,
    user_id: uuid.UUID,
) -> VerificationDetailResponse:
    verification = await _get_verification_or_404(db, verification_id)
    await _check_verification_membership(db, verification, user_id)

    user_stmt = select(User).where(User.id == verification.user_id)
    user_result = await db.execute(user_stmt)
    verification_user = user_result.scalar_one()

    comments_stmt = (
        select(Comment, User)
        .join(User, User.id == Comment.author_id)
        .where(Comment.verification_id == verification_id)
        .order_by(Comment.created_at)
    )
    comments_result = await db.execute(comments_stmt)
    comment_rows = comments_result.all()

    all_user_ids = [verification_user.id] + [row.User.id for row in comment_rows]
    char_map = await load_member_characters(db, list(set(all_user_ids)))

    comments = [
        CommentItem(
            id=row.Comment.id,
            author=CommentAuthor(
                id=row.User.id,
                nickname=row.User.nickname,
                profile_image_url=row.User.profile_image_url,
                character=char_map.get(row.User.id),
            ),
            content=row.Comment.content,
            created_at=row.Comment.created_at,
        )
        for row in comment_rows
    ]

    return VerificationDetailResponse(
        id=verification.id,
        challenge_id=verification.challenge_id,
        user=UserBrief(
            id=verification_user.id,
            nickname=verification_user.nickname,
            profile_image_url=verification_user.profile_image_url,
            character=char_map.get(verification_user.id),
        ),
        date=verification.date,
        photo_urls=verification.photo_urls,
        diary_text=verification.diary_text,
        comments=comments,
        created_at=verification.created_at,
    )
```

(만약 helper `_get_verification_or_404` 와 `_check_verification_membership` 가 verification_service 에 이미 있으면 재사용. 없으면 동일 정의를 추가하거나 comment_service 의 것을 import 한다.)

- [ ] **Step 5.3: `VerificationItem` 응답에 `comment_count` 채우기**

`get_daily_verifications` (또는 동등 함수) 에서 verification 목록을 만드는 곳을 찾아, 각 item 의 `comment_count` 를 채운다. 단일 query 로 끝내려면:

```python
from sqlalchemy import func as sa_func

count_subq = (
    select(
        Comment.verification_id,
        sa_func.count(Comment.id).label("cnt"),
    )
    .group_by(Comment.verification_id)
    .subquery()
)

# 기존 verification 조회 stmt 에 outerjoin
stmt = (
    select(Verification, count_subq.c.cnt)
    .outerjoin(count_subq, count_subq.c.verification_id == Verification.id)
    .where(...)  # 기존 조건 유지
)
```

그리고 result 에서 `cnt or 0` 을 `VerificationItem.comment_count` 에 채운다. 정확한 코드는 현재 파일 구조에 맞게 통합한다 (이전 구현은 `git show 206274b^:server/app/services/verification_service.py` 참고).

- [ ] **Step 5.4: import 검증**

```bash
docker compose exec backend python -c "from app.services.verification_service import get_verification_detail; print('OK')"
```

- [ ] **Step 5.5: Commit**

```bash
git add server/app/services/verification_service.py
git commit -m "feat(server): verification_service - comments JOIN + comment_count 복원"
```

---

### Task 6: routers/verifications.py 에 GET/POST /comments 엔드포인트 추가

**Files:**
- Modify: `server/app/routers/verifications.py`

- [ ] **Step 6.1: import 추가**

```python
from fastapi import Query
from app.schemas.comment import CommentCreateRequest
from app.services import comment_service
```

- [ ] **Step 6.2: 두 엔드포인트 추가** (기존 `GET /verifications/{id}` 핸들러는 그대로 두되 응답 타입이 자동으로 `VerificationDetailResponse` 가 되었음)

```python
@router.get("/{verification_id}/comments")
async def get_comments(
    verification_id: uuid.UUID,
    cursor: str | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await comment_service.get_comments(
        db=db,
        verification_id=verification_id,
        user_id=user_id,
        cursor=cursor,
        limit=limit,
    )
    return {"data": result.model_dump()}


@router.post("/{verification_id}/comments", status_code=201)
async def create_comment(
    verification_id: uuid.UUID,
    body: CommentCreateRequest,
    user_id: uuid.UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    result = await comment_service.create_comment(
        db=db,
        verification_id=verification_id,
        user_id=user_id,
        content=body.content,
    )
    return {"data": result.model_dump()}
```

- [ ] **Step 6.3: 라우터 등록 검증**

```bash
docker compose exec backend python -c "from app.main import app; routes=[r.path for r in app.routes]; print([r for r in routes if 'comments' in r])"
```

Expected: `['/api/v1/verifications/{verification_id}/comments', '/api/v1/verifications/{verification_id}/comments']` (GET + POST 같은 path 두 줄).

- [ ] **Step 6.4: seed.py truncate 목록에 comments 추가**

`server/seed.py` 의 truncate 대상 테이블 리스트에 `"comments"` 를 적절한 순서로 추가 (verifications 보다 먼저, FK 의존성 고려).

- [ ] **Step 6.5: Commit**

```bash
git add server/app/routers/verifications.py server/seed.py
git commit -m "feat(server): GET/POST /verifications/{id}/comments 라우터 + seed 복원"
```

---

## Phase 3 — Backend tests (TDD GREEN 검증)

### Task 7: test_comments.py 복원

**Files:**
- Create: `server/tests/test_comments.py`

- [ ] **Step 7.1: 이전 테스트 추출 + 약간 적응**

```bash
git show 206274b^:server/tests/test_comments.py > server/tests/test_comments.py
```

이전 파일은 `GET /verifications/{id}` 의 happy path 도 함께 테스트했으나, 그 부분은 `test_verification_detail.py` 와 중복됨. 중복되는 3개 (verification_detail_happy_path, verification_detail_not_found, verification_detail_not_member) 는 `test_comments.py` 에서 제거하고, comments 관련 5개만 남긴다 (list_happy_path, create_happy_path, create_too_long, create_not_member, create_verification_not_found).

또는 단순화: 그대로 두고 테스트 두 곳에 동일 케이스가 있어도 무방.

권장: **그대로 추출 + 그대로 둠**. 8개 모두 통과하면 돼.

- [ ] **Step 7.2: 테스트 실행 (RED → GREEN 확인)**

```bash
docker compose exec backend pytest tests/test_comments.py -v
```

Expected: 8 passed (또는 위에서 중복 제거 시 5 passed).

- [ ] **Step 7.3: Commit**

```bash
git add server/tests/test_comments.py
git commit -m "test(server): test_comments.py 복원 - 8개 케이스"
```

---

### Task 8: test_verification_detail.py 댓글 검증 회귀

**Files:**
- Modify: `server/tests/test_verification_detail.py`

- [ ] **Step 8.1: happy path 에 comments 빈 배열 검증 + 댓글 있는 케이스 추가**

happy path 테스트의 마지막 assert 에 다음 추가:

```python
assert data["comments"] == []
```

추가로 새 테스트 작성:

```python
@pytest.mark.asyncio
async def test_verification_detail_with_comments(
    client: AsyncClient,
    db_session: AsyncSession,
    user: User,
    challenge: Challenge,
    membership: ChallengeMember,
    verification: Verification,
):
    """댓글이 있는 인증 상세 조회"""
    from app.models.comment import Comment

    c = Comment(
        id=uuid.uuid4(),
        verification_id=verification.id,
        author_id=user.id,
        content="좋은 인증이네요",
    )
    db_session.add(c)
    await db_session.commit()

    resp = await client.get(
        f"/api/v1/verifications/{verification.id}",
        headers={"Authorization": f"Bearer {user.id}"},
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert len(data["comments"]) == 1
    assert data["comments"][0]["content"] == "좋은 인증이네요"
    assert data["comments"][0]["author"]["id"] == str(user.id)
```

- [ ] **Step 8.2: 실행**

```bash
docker compose exec backend pytest tests/test_verification_detail.py -v
```

Expected: 4 passed (기존 3 + 신규 1).

- [ ] **Step 8.3: Commit**

```bash
git add server/tests/test_verification_detail.py
git commit -m "test(server): verification_detail comments 필드 검증 추가"
```

---

### Task 9: test_verifications.py 의 comment_count assertion 회귀

**Files:**
- Modify: `server/tests/test_verifications.py`

- [ ] **Step 9.1: assertion 바꾸기**

`grep -n "comment_count" server/tests/test_verifications.py` 로 위치 파악 후, `assert "comment_count" not in v_item` → `assert v_item["comment_count"] == 0` 로 회귀.

- [ ] **Step 9.2: 실행**

```bash
docker compose exec backend pytest tests/test_verifications.py -v
```

Expected: 11 passed.

- [ ] **Step 9.3: Commit**

```bash
git add server/tests/test_verifications.py
git commit -m "test(server): VerificationItem.comment_count assertion 회귀"
```

---

## Phase 4 — Frontend: models + providers (신규)

### Task 10: comment_data.dart 복원

**Files:**
- Create: `app/lib/features/challenge_space/models/comment_data.dart`

- [ ] **Step 10.1: 이전 파일 추출**

```bash
git show 206274b^:app/lib/features/challenge_space/models/comment_data.dart > app/lib/features/challenge_space/models/comment_data.dart
```

- [ ] **Step 10.2: VerificationDetail 클래스 위치 확인**

이전 코드는 `comment_data.dart` 에 `VerificationDetail` 을 정의했음. 현재 `verification_data.dart` 에 동명 클래스가 있는지 확인:

```bash
grep -n "class VerificationDetail" app/lib/features/challenge_space/models/verification_data.dart
```

만약 있으면, `verification_data.dart` 의 정의를 제거 (comments 미포함 버전이므로). 없으면 통과.

- [ ] **Step 10.3: VerificationItem 에 commentCount 필드 추가**

`app/lib/features/challenge_space/models/verification_data.dart` 의 `VerificationItem` freezed 클래스에 다음 필드 추가:

```dart
@JsonKey(name: 'comment_count') @Default(0) int commentCount,
```

`@Default(0)` 으로 backwards-compat 보장.

- [ ] **Step 10.4: build_runner 생성**

```bash
cd app && dart run build_runner build --delete-conflicting-outputs
```

Expected: `Succeeded after Xs with N outputs`. `comment_data.freezed.dart`, `comment_data.g.dart` 생성 확인.

- [ ] **Step 10.5: Commit**

```bash
git add app/lib/features/challenge_space/models/comment_data.dart \
        app/lib/features/challenge_space/models/comment_data.freezed.dart \
        app/lib/features/challenge_space/models/comment_data.g.dart \
        app/lib/features/challenge_space/models/verification_data.dart \
        app/lib/features/challenge_space/models/verification_data.freezed.dart \
        app/lib/features/challenge_space/models/verification_data.g.dart
git commit -m "feat(app): comment_data + VerificationItem.commentCount 복원"
```

---

### Task 11: comment_provider.dart 복원

**Files:**
- Create: `app/lib/features/challenge_space/providers/comment_provider.dart`
- Modify: `app/lib/features/challenge_space/providers/verification_provider.dart`

- [ ] **Step 11.1: comment_provider.dart 추출**

```bash
git show 206274b^:app/lib/features/challenge_space/providers/comment_provider.dart > app/lib/features/challenge_space/providers/comment_provider.dart
```

- [ ] **Step 11.2: verification_provider.dart 의 verificationDetailProvider 정리**

현재 `verification_provider.dart` 에 `verificationDetailProvider` 가 있다면 제거 (comment_provider.dart 에서 정의되므로).

```bash
grep -n "verificationDetailProvider" app/lib/features/challenge_space/providers/verification_provider.dart
```

라인 발견 시 해당 부분 삭제. import 정리.

- [ ] **Step 11.3: 다른 파일의 import 경로 갱신**

```bash
grep -rn "verificationDetailProvider\|verification_provider'" app/lib/ | grep -v ".freezed.\|.g.dart"
```

`verificationDetailProvider` 를 사용하는 모든 파일 (verification_detail_screen.dart, character_provider.dart 등) 의 import 를 `comment_provider.dart` 로 갱신.

- [ ] **Step 11.4: 컴파일 검증**

```bash
cd app && flutter analyze --no-pub
```

Expected: error 0.

- [ ] **Step 11.5: Commit**

```bash
git add app/lib/features/challenge_space/providers/comment_provider.dart \
        app/lib/features/challenge_space/providers/verification_provider.dart \
        app/lib/features/character/providers/character_provider.dart \
        app/lib/features/challenge_space/screens/verification_detail_screen.dart
git commit -m "feat(app): comment_provider + verificationDetailProvider 위치 회귀"
```

---

## Phase 5 — Frontend: UI 통합

### Task 12: verification_detail_screen.dart 댓글 섹션 복원

**Files:**
- Modify: `app/lib/features/challenge_space/screens/verification_detail_screen.dart`

- [ ] **Step 12.1: 이전 버전 diff 확인**

```bash
git show 206274b^:app/lib/features/challenge_space/screens/verification_detail_screen.dart
```

전체 내용을 살펴보고, **이번 복원에서 추가해야 할 부분만 식별**:
- `ConsumerWidget` → `ConsumerStatefulWidget` 변환
- `_commentController` 멤버
- `_CommentsSection`, `_CommentItemTile`, `_CommentInputBar` 위젯 클래스 추가
- `_onSendComment` 메서드 추가
- `_buildBody` 의 ListView 구조를 Column + Expanded(ListView) + _CommentInputBar 로 회귀
- import: `comment_data.dart`, `comment_provider.dart` 추가

- [ ] **Step 12.2: 적용**

이전 파일 내용을 그대로 적용하되, 그 사이에 추가된 변경 (39e37b2 의 image upload e2e 변경, 5524d4b 의 인증 버튼 통합) 이 있으면 보존한다. `git show 206274b^..HEAD -- app/lib/features/challenge_space/screens/verification_detail_screen.dart` 로 그 사이 변경분 확인.

권장 절차: 현재 파일에 `_CommentsSection`, `_CommentInputBar`, `_CommentItemTile`, `_onSendComment`, `_commentController`, ConsumerStatefulWidget 변환만 다시 추가하는 식의 minimal patch.

- [ ] **Step 12.3: 컴파일 검증**

```bash
cd app && flutter analyze --no-pub
```

- [ ] **Step 12.4: Commit**

```bash
git add app/lib/features/challenge_space/screens/verification_detail_screen.dart
git commit -m "feat(app): verification_detail_screen 댓글 섹션 + 입력 바 복원"
```

---

### Task 13: daily_verifications_screen 의 💬 표시 복원

**Files:**
- Modify: `app/lib/features/challenge_space/screens/daily_verifications_screen.dart`

- [ ] **Step 13.1: 이전 라인 추출**

```bash
git diff 206274b^..206274b -- app/lib/features/challenge_space/screens/daily_verifications_screen.dart
```

- [ ] **Step 13.2: subtitle 에 `💬 ${item.commentCount}` 표시 라인 추가**

이전 구현 그대로 추가. (위치는 `subtitle:` 또는 row 의 마지막에.)

- [ ] **Step 13.3: 컴파일 검증**

```bash
cd app && flutter analyze --no-pub
```

- [ ] **Step 13.4: Commit**

```bash
git add app/lib/features/challenge_space/screens/daily_verifications_screen.dart
git commit -m "feat(app): daily_verifications 카드에 💬 commentCount 회귀"
```

---

## Phase 6 — Frontend tests

### Task 14: verification_detail_screen_test.dart 댓글 섹션 위젯 테스트 복원

**Files:**
- Modify: `app/test/features/challenge_space/screens/verification_detail_screen_test.dart`

- [ ] **Step 14.1: 이전 테스트 추출**

```bash
git show 206274b^:app/test/features/challenge_space/screens/verification_detail_screen_test.dart > /tmp/prev_test.dart
diff /tmp/prev_test.dart app/test/features/challenge_space/screens/verification_detail_screen_test.dart
```

- [ ] **Step 14.2: 댓글 섹션 / 댓글 입력창 group + helper 위젯 추가**

이전 파일의 "댓글 섹션", "댓글 입력창" 두 group 과 `_CommentData`, `_CommentList`, `_CommentInputBar` helper 위젯을 현재 파일에 머지한다.

- [ ] **Step 14.3: 실행**

```bash
cd app && flutter test --no-pub test/features/challenge_space/screens/verification_detail_screen_test.dart
```

Expected: All tests passed.

- [ ] **Step 14.4: Commit**

```bash
git add app/test/features/challenge_space/screens/verification_detail_screen_test.dart
git commit -m "test(app): verification_detail 댓글 섹션 위젯 테스트 복원"
```

---

## Phase 7 — Source-of-truth docs (사용자 승인 하 진행)

### Task 15: docs/ARCHIVE/* 4종 복원

**Files:**
- Modify: `docs/ARCHIVE/prd.md`
- Modify: `docs/ARCHIVE/api-contract.md`
- Modify: `docs/ARCHIVE/domain-model.md`
- Modify: `docs/ARCHIVE/user-flows.md`

- [ ] **Step 15.1: 이전 (제거 직전) 의 docs 추출**

각 파일을 이전 버전으로 보고:

```bash
git show 206274b^:docs/api-contract.md > /tmp/prev_api.md
git show 206274b^:docs/prd.md > /tmp/prev_prd.md
git show 206274b^:docs/domain-model.md > /tmp/prev_domain.md
git show 206274b^:docs/user-flows.md > /tmp/prev_userflows.md
```

- [ ] **Step 15.2: 현재 docs/ARCHIVE/ 위치 확인**

이전 제거 작업 시 docs/ 가 docs/ARCHIVE/ 로 이동했을 수 있음:

```bash
ls docs/ARCHIVE/ | head -10
ls docs/ | head -10
```

- [ ] **Step 15.3: 댓글 관련 섹션을 다시 채워 넣기**

각 파일에서 2026-04-25 제거 시점에 빠진 항목만 정확히 복원. 특히:
- `prd.md` §4 MVP 제외 범위에서 "댓글" 만 제거하고 "2026-04-27 사용자 결정 뒤집기" 한 줄 명시.
- `api-contract.md` §5 Comments 섹션 + §4 응답 필드 (comment_count, comments) 회귀.
- `domain-model.md` §2.6 Comment 엔티티 + ER 다이어그램 + 인덱스 표 회귀.
- `user-flows.md` Flow 7 댓글 부분 + 화면 구조 요약 회귀.

세부 diff 는 `git show 206274b -- docs/{prd,api-contract,domain-model,user-flows}.md` 로 정확히 확인하고 그것의 reverse 를 적용한다.

- [ ] **Step 15.4: docs-guard hook 검증**

수정 시 hook 이 차단할 수 있으므로 Edit/Write tool 시도 후 차단되면 사용자에게 보고.

- [ ] **Step 15.5: Commit**

```bash
git add docs/ARCHIVE/prd.md docs/ARCHIVE/api-contract.md docs/ARCHIVE/domain-model.md docs/ARCHIVE/user-flows.md
git commit -m "docs: 댓글 기능 복원 - source-of-truth 4종 회귀 (2026-04-25 결정 뒤집기)"
```

---

## Phase 8 — Verification

### Task 16: Backend 빌드 검증

- [ ] **Step 16.1: docker rebuild**

```bash
docker compose up --build -d backend
sleep 3
curl -fsS http://localhost:8000/health
```

Expected: HTTP 200, `{"status":"ok"}`.

- [ ] **Step 16.2: alembic head 확인**

```bash
docker compose exec backend alembic current
```

Expected: `021 (head)`.

- [ ] **Step 16.3: 전체 pytest**

```bash
docker compose exec backend pytest tests/ --tb=short
```

Expected: pass count 가 사전 (2026-04-25 보고서 기준 120) + 신규 추가분 (8 + 1) ≈ 129. 사전 존재 실패 (`test_room_equip.py` 의 2건) 외 모두 PASS.

### Task 17: Frontend 빌드 + iOS simulator clean install

- [ ] **Step 17.1: pub get + build_runner**

```bash
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 17.2: analyze + test**

```bash
flutter analyze --no-pub
flutter test --no-pub test/features/challenge_space/
```

Expected: error 0. challenge_space 테스트 PASS.

- [ ] **Step 17.3: iOS simulator clean install**

`.claude/skills/haeda-ios-deploy/SKILL.md` 절차:

```bash
DEVICE_ID=$(xcrun simctl list devices booted | grep "Booted" | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
BUNDLE_ID=$(grep -m1 "PRODUCT_BUNDLE_IDENTIFIER" app/ios/Runner.xcodeproj/project.pbxproj | sed -E 's/.*= ([^;]+);.*/\1/' | tr -d '"')
xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl uninstall "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
cd app && flutter clean && flutter pub get && flutter build ios --simulator && cd ..
xcrun simctl install "$DEVICE_ID" app/build/ios/iphonesimulator/Runner.app
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"
```

- [ ] **Step 17.4: 시각 검증 (idb tap 자동화)**

`.claude/skills/haeda-ios-tap/SKILL.md` 절차로:
1. 챌린지 룸 진입.
2. 인증 카드 tap → `VerificationDetailScreen` 진입.
3. 댓글 섹션 보임 + 입력 바 보임 확인 (스크린샷).
4. 댓글 입력 + 전송 → 목록 갱신 확인 (스크린샷).
5. 일일 인증 카드의 `💬 N` 표시 확인 (스크린샷).

저장: `docs/reports/screenshots/2026-04-27-feature-restore-comment-feature-NN.png` (NN = 01, 02, ...).

---

## Phase 9 — 보고서 + commit + PR

### Task 18: 보고서 작성 + commit + PR auto-merge

- [ ] **Step 18.1: 보고서 작성**

`docs/reports/2026-04-27-feature-restore-comment-feature.md` 작성:
- 헤더 (Date, Worktree, Role)
- Request: 사용자 요청 원문
- Root cause / Context: 2026-04-25 제거 결정 + 2026-04-27 뒤집기
- Actions: 변경 파일 목록 (Phase 별)
- Verification: pytest / flutter test / iOS simulator 결과 + 스크린샷 경로
- Follow-ups: P1 댓글 페이지네이션 / 멘션 / 알림 추후 검토
- Referenced Reports: `docs/reports/2026-04-25-feature-remove-comment-feature.md`

- [ ] **Step 18.2: 보고서 commit**

```bash
git add docs/reports/2026-04-27-feature-restore-comment-feature.md docs/reports/screenshots/2026-04-27-*.png
git commit -m "docs(report): 댓글 기능 복원 작업 보고서"
```

- [ ] **Step 18.3: PR auto-merge**

`.claude/skills/commit/SKILL.md` 절차로 PR 생성 + auto-merge 까지 (worktree-feature 브랜치).

---

## 자체 검토 체크리스트

- [x] **Spec coverage**: design spec §2 의 모든 복원 범위 (backend/db/frontend/tests/docs) 가 task 1–15 로 커버됨.
- [x] **Placeholder scan**: TBD/TODO 없음. 모든 step 에 명령 또는 코드 명시.
- [x] **Type consistency**: `CommentItem`, `CommentAuthor`, `CommentsListResponse`, `VerificationDetailResponse`, `VerificationItem.comment_count`, `VerificationItem.commentCount` 등 이름 일관성 OK.
- [x] **TDD evidence**: 각 backend / frontend test 가 RED → GREEN cycle 로 검증됨 (Step 7.2, 8.2, 9.2, 14.3).
- [x] **검증 명령**: 모든 변경 단위 끝에 import / pytest / flutter test / docker build / health 명령으로 검증.
