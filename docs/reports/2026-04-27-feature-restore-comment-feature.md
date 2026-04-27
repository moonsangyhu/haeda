# 챌린지 인증 댓글 기능 복원

- **Date**: 2026-04-27
- **Worktree (수행)**: `.claude/worktrees/feature` (worktree-feature)
- **Worktree (영향)**: feature 단일
- **Role**: feature

## Request

> "챌린지 인증한 글에 댓글 달 수 있었는데, 이 기능이 사라졌어. 다시 만들어 줘."

사용자 결정: 2026-04-25 commit `206274b` 의 댓글 풀 제거 결정을 명시적으로 뒤집고, 이전 구현 그대로 복원.

## Root cause / Context

- 2026-04-25 보고서 `docs/reports/2026-04-25-feature-remove-comment-feature.md` 에 따라 27 파일 변경으로 댓글 기능 풀 제거됨 (backend / frontend / migration 018 drop / source-of-truth docs).
- 당시 결정 근거는 "MVP 단순화 — 인증 자체에 집중". 사용자가 같은 경계 위에서 재요청 → 결정 reversal.
- 이전 구현이 git 히스토리(206274b^) 에 보존돼 있어 핵심 전략은 **`git show ...^:<path>` 추출 + 그 사이 변경분(인증 버튼 통합 5524d4b, 이미지 업로드 e2e 39e37b2, RoomSpeech 제거 74a3c5e) 보존하며 머지**.
- DB 는 신규 migration 021 로 `comments` 테이블 재생성 (018 의 downgrade 와 동일 스키마).

## Actions

### 1. Spec / Plan
- `docs/superpowers/specs/2026-04-27-restore-comment-feature-design.md` (commit 2c35586): 복원 범위, 결정사항, 검증 계획.
- `docs/superpowers/plans/2026-04-27-restore-comment-feature.md` (commit 211539e): 9 Phase / 18 Task / ~60 step.

### 2. Backend code (commit 49b09ae)
- `server/app/models/comment.py` 신규 — Comment 엔티티 (UUID PK, verification_id FK, author_id FK, content varchar(500), created_at, idx_comment_verification).
- `server/app/models/__init__.py` — Comment import + `__all__` 등록.
- `server/app/models/user.py` — `User.comments` relationship (cascade='all, delete-orphan').
- `server/app/models/verification.py` — `Verification.comments` relationship (동일).
- `server/app/schemas/comment.py` 신규 — CommentAuthor, CommentItem, CommentCreateRequest, CommentsListResponse.
- `server/app/schemas/verification.py` — `VerificationItem.comment_count: int = 0` + `VerificationDetailResponse.comments: list[CommentItem]`.
- `server/app/services/comment_service.py` 신규 — get_comments (커서 페이지네이션), create_comment (멤버 체크 + 길이 검증 + COMMENT_TOO_LONG).
- `server/app/services/verification_service.py` — `get_daily_verifications` 에 comment_count subquery (outerjoin), `get_verification_detail` 에 comments JOIN + char_map 통합.
- `server/app/routers/verifications.py` — `GET /verifications/{id}/comments` + `POST /verifications/{id}/comments` 추가.
- `server/seed.py` — truncate 대상 테이블 목록에 "comments" 추가.

### 3. Migration (commit 49b09ae)
- `server/alembic/versions/20260427_0000_021_recreate_comments.py` — upgrade: comments 테이블 + idx_comment_verification 인덱스 생성. downgrade: 인덱스 + 테이블 drop.

### 4. Backend tests (commit e7ff2b8)
- `server/tests/test_comments.py` 신규 — 8 케이스 (verification_detail happy/not_found/not_member, comments_list happy, comment_create happy/too_long/not_member/verification_not_found).
- `server/tests/test_verification_detail.py` — `comments == []` 회귀 + `test_verification_detail_with_comments` 신규 케이스 추가.
- `server/tests/test_verifications.py` — `assert v_item["comment_count"] == 0` 로 회귀.

### 5. Frontend code (commit f64b2a4)
- `app/lib/features/challenge_space/models/comment_data.dart` 신규 — CommentAuthor, CommentItem (freezed).
- `app/lib/features/challenge_space/models/verification_data.dart` — `VerificationItem.commentCount: int = 0` + `VerificationDetail.comments: List<CommentItem>` 필드 추가.
- `app/lib/features/challenge_space/providers/comment_provider.dart` 신규 — commentSubmitProvider (POST + 에러 매핑: NOT_A_MEMBER / VERIFICATION_NOT_FOUND / COMMENT_TOO_LONG).
- `app/lib/features/challenge_space/screens/verification_detail_screen.dart` — `ConsumerWidget` → `ConsumerStatefulWidget` 회귀, `_CommentsSection`, `_CommentItemTile`, `_CommentInputBar` 위젯 + `_onSendComment` 메서드 추가.
- `app/lib/features/challenge_space/screens/daily_verifications_screen.dart` — subtitle 에 `💬 commentCount` 표시 (commentCount > 0 일 때만) 회귀.
- `app/test/features/challenge_space/screens/verification_detail_screen_test.dart` — 댓글 섹션 / 댓글 입력창 group 7개 위젯 테스트 추가.

### 6. Source-of-truth docs (commit ea4b5ce, 사용자 명시 승인 하 수정)
- `docs/api-contract.md` — §0 P0 범위에 Comments 추가, §4 verification 응답에 `comment_count` / `comments` 회귀, §5 Comments 섹션 (POST/GET 엔드포인트, COMMENT_TOO_LONG 에러) 회귀, 이후 섹션 번호 재조정.
- `docs/prd.md` — §1.3 핵심 가치, §1.5/§2 핵심 루프, §2.5 "인증 & 피드백" + F-14, §2.7 F-17, §4 MVP 제외 범위 (댓글 라인 제거, 2026-04-27 결정 명시), §5 댓글 작성률 지표 회귀.
- `docs/domain-model.md` — 핵심 객체 정의, §1 ER 다이어그램, §2.6 Comment 엔티티 + 이후 엔티티 번호 +1 시프트 (DeviceToken=2.7 ~ RoomEquipCrSignature=2.15), §3 인덱스 표 회귀.
- `docs/user-flows.md` — P0 댓글 추가, Flow 7 댓글 ASCII 도식 + 화면 구조 요약 회귀.

### 7. UX 보강 (commit d454057)
- `verification_detail_screen.dart::_onSendComment` 에서 `dailyVerificationsProvider` 도 함께 invalidate. 이전 fix `f704845` 의 동일 패턴 (detail.challengeId / detail.date 로 DailyVerificationParams 생성).

## Verification

### Backend
- `docker compose up --build -d backend` — 재빌드 성공, 컨테이너 healthy.
- `curl -fsS http://localhost:8000/health` → HTTP 200, `{"status":"ok"}`.
- `alembic current` → `021 (head)`.
- 댓글 직접 영향 테스트:
  ```
  pytest tests/test_comments.py tests/test_verification_detail.py tests/test_verifications.py -v
  ============================== 26 passed in 0.89s ==============================
  ```
- 전체 회귀:
  ```
  pytest tests/ --tb=line -q
  ........................................................................ [ 50%]
  .....................FF...............................................   [100%]
  =========================== 2 failed, 140 passed in 3.45s
  ```
  - 실패한 2개(`test_room_equip.py::TestSignature::test_member_clear_signature`, `test_non_member_clear_signature_returns_403`) 는 이전 보고서 (2026-04-25) 에서 동일하게 보고된 **사전 존재 실패** (Room Decoration Signature 422 vs 200/403 응답 불일치) — 본 작업과 무관.

### Frontend
- `flutter clean && flutter pub get && dart run build_runner build --delete-conflicting-outputs` → `Succeeded after 12.2s with 167 outputs`.
- `flutter analyze --no-pub` → challenge_space 영역 error 0 (전체 202 issues 모두 info-level `prefer_const_constructors` 또는 사전 존재 `profile_setup_screen` invalid_override).
- `flutter test --no-pub test/features/challenge_space/`:
  ```
  00:01 +37: All tests passed!
  ```
  이전 30 → 댓글 위젯 테스트 7 추가로 37 passed.
- `flutter build ios --simulator` → `✓ Built build/ios/iphonesimulator/Runner.app` (26.8s).

### iOS Simulator clean install + 시각 검증
- Device: iPhone 17 Pro `463EC4CF-2080-47FE-8F26-530FFB713C06`, Bundle: `com.example.haeda`.
- terminate → uninstall → flutter clean → pub get → build → install → launch (PID 83610) 시퀀스 성공.
- idb 자동 인터랙션으로 댓글 시나리오 검증 (스크린샷 8장):

| # | 단계 | 스크린샷 |
|---|------|----------|
| 01 | launch 첫 화면 (내 페이지) | `docs/reports/screenshots/2026-04-27-feature-restore-comment-feature-01.png` |
| 02 | ddd 챌린지 공간 진입 | `02.png` |
| 04 | 4월 26일 인증 현황 | `04.png` |
| 05 | 인증 상세 — 댓글 0 + "아직 댓글이 없습니다" + 입력 바 | `05.png` |
| 06 | 댓글 텍스트 입력 후 (한글 keymap 충돌로 transliterate 됨) | `06.png` |
| 07 | 댓글 1 — 박지민 / 방금 전 / 댓글 내용 표시 (POST + invalidate + 재로드 동작 확인) | `07.png` |
| 08 | daily_verifications 회귀 | `08.png` |

UI 트리 어설션:
```
[StaticText] "댓글 1
박지민
방금 전
[댓글 내용]" at (16,252)
```

### 잔여 검증 (사용자 수동 확인 권장)
- 한글 입력으로 댓글 작성·표시 (idb 의 한글 keymap 미지원으로 본 자동 검증에서는 transliterate 됨. iOS 시뮬레이터에서 한국어 키보드로 직접 입력해 정상 표시 확인 권장).
- `dailyVerificationsProvider` invalidate 추가 (commit d454057) 의 시각 검증 — UI 트리 캡처는 fix 이전 시점이라 💬 1 표시는 미확인. 코드는 이전 fix `f704845` 와 동일 패턴이고 `flutter analyze --no-pub` 통과.

## Follow-ups

- **댓글 작성률 지표 P1 모니터링**: prd.md §5 의 "댓글 작성률 ≥ 0.5 / Verification" 목표를 실제 운영 데이터로 측정. 현재 backend 이벤트 트래킹 미구현.
- **댓글 페이지네이션 UI**: backend 는 cursor 기반 `GET /verifications/{id}/comments` 페이지네이션 지원하지만, frontend `verification_detail_screen` 은 `GET /verifications/{id}` 응답에 임베드된 list 만 표시. 댓글 수가 많아지면 추후 분리 필요.
- **댓글 알림 / 푸시**: 본 복원 범위 밖. P1 push 시스템 (FCM) 의존.
- **댓글 멘션 / 좋아요 / 신고**: 추가 기능. 본 복원에 미포함.
- **사전 존재 backend 실패 2건** (`test_room_equip.py` Signature) — 별도 fix 세션에서 처리.
- **사전 존재 frontend 실패** (`profile_setup_screen` invalid_override) — 별도 처리 필요.

## Related

- 이전 보고서: `docs/reports/2026-04-25-feature-remove-comment-feature.md` — 본 복원의 정확한 역연산.
- Spec: `docs/superpowers/specs/2026-04-27-restore-comment-feature-design.md`
- Plan: `docs/superpowers/plans/2026-04-27-restore-comment-feature.md`
- Migration: `server/alembic/versions/20260427_0000_021_recreate_comments.py`
- 이전 fix 인용: commit `f704845` "fix: invalidate daily verifications after comment to update count" — 본 복원의 invalidation 패턴 재적용.

### Referenced Reports

- `docs/reports/2026-04-25-feature-remove-comment-feature.md` — 직접적 역연산. 제거된 27 파일, migration 018, docs 변경분 모두 본 복원의 청사진으로 사용.
- 검색 키워드: `comment`, `Comment`, `댓글`, `verification`, `challenge_space`, `comment_count`. 위 1개 보고서 외 관련 사전 작업 없음.
