# 챌린지 인증 댓글 기능 복원

- **Date**: 2026-04-27
- **PR**: #69 (merged 2026-04-27T09:44Z)
- **Area**: both (backend + frontend + docs)

## What Changed

2026-04-25 commit `206274b` 가 풀 제거한 댓글 기능을 사용자 재요청으로 복원. 이전 구현이 git 히스토리에 보존되어 있어 코드 추출 + 그 사이 변경분 보존 머지로 진행. DB 는 신규 alembic migration 021 로 `comments` 테이블을 재생성했고, source-of-truth 4종 docs 의 댓글 관련 항목도 회귀 (§4 MVP 제외 범위에 결정 reversal 명시).

## Changed Files

| File | Change |
|------|--------|
| `server/app/models/comment.py` | 신규 — Comment 엔티티 |
| `server/app/models/{__init__,user,verification}.py` | Comment relationship 회귀 |
| `server/app/schemas/comment.py` | 신규 — CommentAuthor / CommentItem / CommentCreateRequest / CommentsListResponse |
| `server/app/schemas/verification.py` | VerificationItem.comment_count + VerificationDetailResponse.comments |
| `server/app/services/comment_service.py` | 신규 — list / create (커서 페이지네이션 + COMMENT_TOO_LONG) |
| `server/app/services/verification_service.py` | comment_count subquery + comments JOIN |
| `server/app/routers/verifications.py` | GET / POST /verifications/{id}/comments |
| `server/seed.py` | truncate 목록 회귀 |
| `server/alembic/versions/20260427_0000_021_recreate_comments.py` | 신규 migration |
| `server/tests/test_comments.py` | 신규 8 케이스 |
| `server/tests/test_verification_detail.py` | comments 검증 + with_comments 케이스 |
| `server/tests/test_verifications.py` | comment_count assertion 회귀 |
| `app/lib/features/challenge_space/models/comment_data.dart` | 신규 (freezed) |
| `app/lib/features/challenge_space/models/verification_data.dart` | commentCount + comments 필드 |
| `app/lib/features/challenge_space/providers/comment_provider.dart` | 신규 |
| `app/lib/features/challenge_space/screens/verification_detail_screen.dart` | ConsumerStatefulWidget + 댓글 섹션 + 입력 바 + dailyVerificationsProvider invalidate |
| `app/lib/features/challenge_space/screens/daily_verifications_screen.dart` | 💬 commentCount 회귀 |
| `app/test/features/challenge_space/screens/verification_detail_screen_test.dart` | 댓글 위젯 테스트 7 추가 |
| `docs/prd.md` | 핵심 가치 / 핵심 루프 / §2.5 / F-14 / §4 MVP 제외 범위 / §5 댓글 작성률 |
| `docs/api-contract.md` | §0 P0 / §4 응답 / §5 Comments 엔드포인트 |
| `docs/domain-model.md` | 핵심 객체 / ER / §2.6 Comment + 번호 시프트 / 인덱스 |
| `docs/user-flows.md` | P0 / Flow 7 ASCII / 화면 구조 |
| `docs/superpowers/specs/2026-04-27-restore-comment-feature-design.md` | spec |
| `docs/superpowers/plans/2026-04-27-restore-comment-feature.md` | plan |
| `docs/reports/2026-04-27-feature-restore-comment-feature.md` | 작업 보고서 + 스크린샷 8장 |

## Implementation Details

### 책임 분리 (이전과 약간 다름)
- 이전: `comment_service.py` 가 `get_verification_detail` + 댓글 CRUD 모두 담당.
- 이번: `verification_service.py` 가 `get_verification_detail` (comments JOIN 포함) + `get_daily_verifications` (comment_count subquery) 담당. `comment_service.py` 는 댓글 list / create 만.
- 이유: 책임 분리가 더 명확. `verification_*` 응답은 verification_service 가, comments CRUD 는 comment_service 가.

### Migration 전략
- 018 (drop comments) 이후 020 까지 진행된 상태. 새 revision 021 (recreate) 로 복원. `down_revision = "020"`.
- 018 의 downgrade 와 021 의 upgrade 가 동일 스키마 (UUID id PK / verification_id FK / author_id FK / content varchar(500) / created_at + idx_comment_verification 인덱스).

### 동시 변경 보존
206274b 이후 verification 영역에 4건 변경:
- 5524d4b (인증 버튼 통합) — 보존
- 6ef050f (coins_earned type fix) — 보존
- 39e37b2 (image upload e2e) — 보존
- 74a3c5e (RoomSpeech 제거) — 영향 없음

### UX 보강
이전 fix `f704845` 가 댓글 작성 후 dailyVerificationsProvider invalidation 을 추가했었음. 본 복원에서 누락 → iOS simulator 검증에서 발견 → commit `d454057` 로 동일 패턴 재적용.

### 사용자 결정 reversal 기록
prd.md §4 MVP 제외 범위:
- 2026-04-25: "채팅 / 댓글 / 실시간 메시지 / 챌린지 방 한마디 ... 2026-04-25 사용자 결정으로 댓글·Room Speech 기능 모두 제거"
- 2026-04-27: "채팅 / 실시간 메시지 / 챌린지 방 한마디 ... 2026-04-25 Room Speech 제거. 댓글은 2026-04-27 사용자 재요청으로 복원"

## Tests & Build

- Backend pytest: 26 passed (직접 영향) + 140 passed (전체, 사전 실패 2건 무관 — `test_room_equip.py` Signature)
- alembic: `021 (head)`
- /health: 200 OK
- Flutter analyze: challenge_space error 0
- Flutter test: 37 passed (이전 30 + 댓글 위젯 7)
- Flutter build ios --simulator: 26.8s
- iOS simulator clean install + idb 자동 8단계 시각 검증: 댓글 작성 → "댓글 1 / 박지민 / 방금 전 / 내용" 표시 확인
