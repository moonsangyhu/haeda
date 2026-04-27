# 챌린지 인증 댓글 기능 복원 — Design Spec

- **Date**: 2026-04-27
- **Author**: Claude (worktree-feature)
- **Status**: ready
- **Type**: feature restoration (regression-prevention undo)
- **Source-of-truth Impact**: prd.md / api-contract.md / domain-model.md / user-flows.md (4 files) — 사용자 승인 필요

## 1. 배경

2026-04-25 커밋 `206274b refactor: 챌린지 방 댓글(Comment) 기능 전체 제거` 에서 사용자 결정으로 댓글 기능 풀 제거. 보고서 `docs/reports/2026-04-25-feature-remove-comment-feature.md` 에 27개 파일 변경, alembic migration 018 (drop comments) 적용, MVP 제외 범위에 영구 기록.

2026-04-27 사용자 재요청: **"챌린지 인증한 글에 댓글 달 수 있었는데, 이 기능이 사라졌어. 다시 만들어 줘."**

본 spec 은 2026-04-25 결정을 명시적으로 뒤집고, 제거된 기능을 그대로 복원하는 것을 목표로 한다. 이전 spec 은 git 히스토리(206274b 의 reverse) 에 보존되어 있어 신규 설계가 아닌 "복원" 으로 진행한다.

## 2. 복원 범위 (= 206274b 가 제거한 모든 것)

### 2.1 Backend
- `server/app/models/comment.py` — `Comment` 모델 (UUID id PK, verification_id FK, author_id FK, content varchar(500), created_at).
- `server/app/models/user.py` — `User.comments` relationship (cascade delete).
- `server/app/models/verification.py` — `Verification.comments` relationship (cascade delete).
- `server/app/models/__init__.py` — `Comment` import / export 복원.
- `server/app/schemas/comment.py` — `CommentCreate` (content min_length=1, max_length=500), `CommentItem`, `CommentListResponse`.
- `server/app/schemas/verification.py` — `VerificationDetailResponse` 에 `comments: list[CommentItem]` 필드 복원, `VerificationItem.comment_count: int` 필드 복원.
- `server/app/services/comment_service.py` — `list_comments`, `create_comment` (멤버 체크 + 길이 검증 + COMMENT_TOO_LONG 에러 포함). 인증 작성자/멤버만 댓글 가능 정책은 이전 제거 시점과 동일하게 "챌린지 멤버만" 으로 유지.
- `server/app/services/verification_service.py` — `get_verification_detail()` 에서 `Comment` join + `comment_count` 집계 복원, `VerificationItem` 응답에 `comment_count` 채우기 복원.
- `server/app/routers/verifications.py` — `GET /verifications/{id}/comments` + `POST /verifications/{id}/comments` 두 엔드포인트 복원, `GET /verifications/{id}` 응답 스키마를 `VerificationDetailResponse` 로 교체.
- `server/seed.py` — truncate 대상 테이블 목록에 `"comments"` 복원.

### 2.2 Database
- `server/alembic/versions/20260427_0000_021_recreate_comments.py` 신규 작성:
  - `down_revision = "020"`.
  - `upgrade`: `comments` 테이블 + `idx_comment_verification` 인덱스 재생성 (018 의 downgrade 와 동일 스키마).
  - `downgrade`: 인덱스 + 테이블 drop.

### 2.3 Frontend
- `app/lib/features/challenge_space/models/comment_data.dart` (+ `*.freezed.dart`, `*.g.dart`) 복원.
- `app/lib/features/challenge_space/models/verification_data.dart`:
  - `VerificationItem.commentCount: int` 필드 복원.
  - `VerificationDetail` 클래스 정의를 `verification_data.dart` 에서 제거 (있다면), `comment_data.dart` 의 `VerificationDetail` (comments 포함) 으로 회귀.
- `app/lib/features/challenge_space/providers/comment_provider.dart` 복원 (commentListProvider, commentSubmitProvider, verificationDetailProvider invalidation 포함).
- `app/lib/features/challenge_space/providers/verification_provider.dart` 의 `verificationDetailProvider` 정의는 `comment_provider.dart` 로 이동/재정의 (이전과 동일 위치).
- `app/lib/features/challenge_space/screens/verification_detail_screen.dart`:
  - `_CommentsSection`, `_CommentItemTile`, `_CommentInputBar`, `_onSendComment`, `_commentController` 복원.
  - `ConsumerWidget` → `ConsumerStatefulWidget` 으로 회귀.
  - 단, 그 사이 추가된 변경 (e.g. 39e37b2 image upload e2e, 5524d4b 인증 버튼 통합) 은 보존한다.
- `app/lib/features/challenge_space/screens/daily_verifications_screen.dart` — `💬 ${item.commentCount}` 표시 라인 복원.
- `app/lib/features/character/providers/character_provider.dart` — 필요 시 `comment_provider` import 복원 (verificationDetailProvider 위치에 따라).

### 2.4 Tests
- Backend
  - `server/tests/test_comments.py` 복원 (이전 8개 테스트: 길이 검증, 멤버 체크, 비멤버 403, 권한 에러, COMMENT_TOO_LONG, 목록 페이지네이션 없음, 시간순 정렬, NOT_FOUND).
  - `server/tests/test_verification_detail.py` 의 happy path 에 `comments` 필드 검증 복원.
  - `server/tests/test_verifications.py` 의 `assert "comment_count" not in v_item` → `assert v_item["comment_count"] == 0` 로 회귀.
- Frontend
  - `app/test/features/challenge_space/screens/verification_detail_screen_test.dart` 의 "댓글 섹션" / "댓글 입력창" group 복원, helper 위젯 (`_CommentData`, `_CommentList`, `_CommentInputBar`) 복원.

### 2.5 Source-of-truth Docs (사용자 승인 필요)
- `docs/ARCHIVE/prd.md`:
  - §1.3 핵심 가치 "사진 + 일기" → "사진 + 일기 + 댓글" 회귀.
  - §1.5 / §2 / §2.5 / §2.7 / §5 의 댓글 항목 회귀 (커밋 206274b 이전 상태).
  - §4 MVP 제외 범위: "채팅 / 댓글 / 실시간 메시지" 한 줄에서 "댓글" 만 제거 + 2026-04-27 결정 명시 ("2026-04-25 제거 결정 뒤집음").
  - F-14 (참여자 간 댓글) 항목 복원, §2.5 섹션명 "인증" → "인증 & 피드백" 회귀.
- `docs/ARCHIVE/api-contract.md`:
  - §0 P0 범위 목록에 Comments 추가.
  - §4 Verifications 응답에 `comment_count`, `comments` 필드 복원.
  - §5 Comments 섹션 (POST/GET 엔드포인트, COMMENT_TOO_LONG 에러) 복원, 이후 섹션 번호 재조정 (Coins=6, Shop=7, Character=8, Notifications=9, Push=10).
- `docs/ARCHIVE/domain-model.md`:
  - 핵심 객체 정의에 댓글 회귀.
  - §1 ER 다이어그램에 Comment 노드 회귀.
  - §2 Comment 엔티티 정의 복원, 이후 엔티티 번호 재조정.
  - §3 인덱스 표에 `idx_comment_verification` 회귀.
- `docs/ARCHIVE/user-flows.md`:
  - P0 범위 목록에 댓글 추가.
  - Flow 7 제목 "인증 내역 조회" → "인증 내역 조회 & 댓글" 회귀.
  - Flow 7 본문에 댓글 목록 / 입력 박스 ASCII 도식 복원.
  - 화면 구조 요약 "인증 상세 (사진+일기)" → "인증 상세 (사진+일기+댓글)" 회귀.

## 3. 주요 결정사항 (Decisions)

### D1. 복원 방식: git reverse-patch + 수동 통합
**선택**: 가능한 부분은 `git show 206274b -- <path>` 의 reverse-patch 로 정확히 복원. 그 사이 변경된 파일 (verification_service.py, verification_detail_screen.dart, daily_verifications_screen.dart, schemas/verification.py 등) 은 reverse-patch 가 conflict 날 가능성 있어 수동 통합.

대안: 처음부터 코드 재작성 — 거부. 이전 구현은 검증 완료된 상태이고 규모가 27 파일이라 재작성 효율이 나쁨.

### D2. Migration: 신규 revision 021
**선택**: 018 (drop comments) 을 그대로 두고 021 (recreate comments) 신규 작성. 018 의 downgrade 와 021 의 upgrade 가 동일 스키마.

대안: 018 자체를 revert — 거부. 이미 적용된 마이그레이션을 사후에 수정하면 production-state 와 코드의 일관성이 깨진다.

### D3. 동시 변경 보존: 그 사이 commit 4건의 변경분 유지
**선택**:
- `5524d4b refactor(front): 챌린지 방 인증하기 버튼 제거 + 캘린더 날짜 tap 으로 통합` — verification_detail_screen 의 인증 버튼 회귀시키지 않음.
- `6ef050f fix(backend): 인증 제출 응답 coins_earned 필드 type 으로 정정` — 그대로 유지.
- `39e37b2 feat: 챌린지 인증 이미지 업로드 로컬 테스트 환경 셋팅` — 인증 이미지 업로드 변경분 유지.
- `74a3c5e refactor: 챌린지 방 한마디(RoomSpeech) 기능 전체 제거` — RoomSpeech 는 유지(즉, 제거된 채로 둠).

### D4. 댓글 권한: "챌린지 멤버만" 정책 회귀
**선택**: 이전 구현과 동일하게 챌린지 멤버 체크 + 비멤버 시 `NOT_A_MEMBER` 또는 `FORBIDDEN` (이전 코드 그대로).

### D5. UX 추가/축소 없음
**선택**: 이번 복원에서는 새 기능 추가하지 않음 (멘션, 좋아요, 신고, 푸시 알림, 페이지네이션 등). 이전 상태 그대로 복원만.

## 4. 비복원 (의도적 제외)

- 댓글 알림 (push) — 이전에도 없었음.
- 댓글 페이지네이션 — 이전 응답이 list 통째로 반환했음. 그대로.
- 댓글 멘션·좋아요·신고 — 추가 기능. 이번 범위 밖.
- 댓글 수정·삭제 — 이전 구현 시점에도 미구현. 그대로.

## 5. 검증 계획

### 5.1 Backend
1. `docker compose up --build -d backend` → 빌드 성공.
2. `docker compose exec backend alembic upgrade head` → migration 021 적용 확인.
3. `curl -fsS http://localhost:8000/health` → HTTP 200 + `{"status":"ok"}`.
4. `docker compose exec backend pytest tests/test_comments.py tests/test_verification_detail.py tests/test_verifications.py` → 모든 케이스 PASS.
5. 전체 `pytest tests/` → 사전 존재 실패 외 모두 PASS.

### 5.2 Frontend
1. `cd app && flutter pub get && dart run build_runner build --delete-conflicting-outputs` → freezed/g.dart 생성 성공.
2. `flutter analyze --no-pub` → error 0.
3. `flutter test --no-pub test/features/challenge_space/` → All tests passed.
4. `flutter build ios --simulator` → 빌드 성공.

### 5.3 iOS Simulator (시각 검증)
- `haeda-ios-deploy` skill: terminate → uninstall → clean → pub get → build → install → launch.
- `haeda-ios-tap` 으로 인증 상세 화면 진입 → 댓글 섹션 + 입력 바 보임 → 댓글 작성 → 목록 갱신 + 일일 인증 카드의 `💬 N` 증가 확인. 단계별 스크린샷을 `docs/reports/screenshots/2026-04-27-feature-restore-comment-feature-NN.png` 로 저장.

## 6. TDD 사이클 (RED → GREEN)

각 변경 단위마다:

1. **Backend (test_comments.py)**: 8개 테스트 RED 로 추가 → 모델/schema/service/router 구현 → GREEN.
2. **Backend (test_verification_detail.py)**: comments 필드 검증 추가 → service / schema 수정 → GREEN.
3. **Backend (test_verifications.py)**: comment_count assertion 회귀 → schema/service 수정 → GREEN.
4. **Frontend (verification_detail_screen_test.dart)**: 댓글 섹션 widget test 추가 → screen 복원 → GREEN.

## 7. 위험 / 주의사항

- 이전 결정 (`prd §4 MVP 제외 범위`) 을 뒤집는 작업이라 docs 변경분이 큼. 사용자 승인 1회 필요 (auto mode 에서도 source-of-truth 변경은 confirm 대상으로 간주).
- Migration 021 적용 후 production-like 환경에서 댓글 데이터는 빈 상태로 시작. 기존 데이터 복구는 불가능 (018 drop 시점에 데이터 손실됨).
- `git show 206274b -- <path>` 의 reverse-patch 가 conflict 나는 파일은 수동 머지로 처리. "그 사이 변경분 보존" 원칙을 항상 우선.

## 8. Out of Scope

- 신규 댓글 UX (페이지네이션, 멘션, 좋아요).
- 댓글 알림 / 푸시 / 이메일.
- 댓글 통계 / 어드민.

## 9. Referenced Reports

- `docs/reports/2026-04-25-feature-remove-comment-feature.md` — 이번 복원의 정확한 역연산이 되는 제거 작업 보고서. 제거된 파일 목록, migration, docs 변경분, 검증 결과 모두 인용.
- 검색 키워드: `comment`, `Comment`, `댓글`, `verification`, `challenge_space`.

## 10. 다음 단계

1. 본 spec 을 `docs/superpowers/specs/2026-04-27-restore-comment-feature-design.md` 로 commit.
2. `superpowers:writing-plans` 스킬로 implementation plan 작성 → `docs/superpowers/plans/2026-04-27-restore-comment-feature.md`.
3. plan 따라 TDD 구현.
4. 검증 + 시뮬레이터 시각 확인.
5. 작업 보고서 + commit + PR auto-merge.
