import uuid
from datetime import datetime, timezone

from sqlalchemy import select
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
    VerificationDetailResponse,
)
from app.schemas.user import UserBrief


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


async def get_verification_detail(
    db: AsyncSession,
    verification_id: uuid.UUID,
    user_id: uuid.UUID,
) -> VerificationDetailResponse:
    # 1. Verification 조회
    verification = await _get_verification_or_404(db, verification_id)

    # 2. 멤버십 확인
    await _check_verification_membership(db, verification, user_id)

    # 3. Verification 작성자 조회
    user_stmt = select(User).where(User.id == verification.user_id)
    user_result = await db.execute(user_stmt)
    verification_user = user_result.scalar_one()

    # 4. 댓글 목록 조회 (작성자 JOIN)
    comments_stmt = (
        select(Comment, User)
        .join(User, User.id == Comment.author_id)
        .where(Comment.verification_id == verification_id)
        .order_by(Comment.created_at)
    )
    comments_result = await db.execute(comments_stmt)
    comment_rows = comments_result.all()

    comments = [
        CommentItem(
            id=row.Comment.id,
            author=CommentAuthor(
                id=row.User.id,
                nickname=row.User.nickname,
                profile_image_url=row.User.profile_image_url,
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
        ),
        date=verification.date,
        photo_urls=verification.photo_urls,
        diary_text=verification.diary_text,
        comments=comments,
        created_at=verification.created_at,
    )


async def get_comments(
    db: AsyncSession,
    verification_id: uuid.UUID,
    user_id: uuid.UUID,
    cursor: str | None,
    limit: int,
) -> CommentsListResponse:
    # 1. Verification 조회
    verification = await _get_verification_or_404(db, verification_id)

    # 2. 멤버십 확인
    await _check_verification_membership(db, verification, user_id)

    # 3. 커서 기반 페이지네이션으로 댓글 조회
    #    커서는 "created_at|id" 복합 키로 동일 타임스탬프 레코드 누락 방지
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
        from sqlalchemy import or_, and_, tuple_

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

    # limit + 1개 조회해서 next_cursor 판별
    stmt = stmt.limit(limit + 1)
    result = await db.execute(stmt)
    rows = result.all()

    has_next = len(rows) > limit
    page_rows = rows[:limit]

    comments = [
        CommentItem(
            id=row.Comment.id,
            author=CommentAuthor(
                id=row.User.id,
                nickname=row.User.nickname,
                profile_image_url=row.User.profile_image_url,
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

    return CommentsListResponse(
        comments=comments,
        next_cursor=next_cursor,
    )


async def create_comment(
    db: AsyncSession,
    verification_id: uuid.UUID,
    user_id: uuid.UUID,
    content: str,
) -> CommentItem:
    # 1. 댓글 길이 검증
    if len(content) > 500:
        raise AppException(
            status_code=422,
            code="COMMENT_TOO_LONG",
            message="댓글은 500자를 초과할 수 없습니다.",
        )

    # 2. Verification 조회
    verification = await _get_verification_or_404(db, verification_id)

    # 3. 멤버십 확인
    await _check_verification_membership(db, verification, user_id)

    # 4. 작성자 조회
    user_stmt = select(User).where(User.id == user_id)
    user_result = await db.execute(user_stmt)
    author = user_result.scalar_one()

    # 5. Comment 레코드 생성
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
        ),
        content=comment.content,
        created_at=comment.created_at,
    )
