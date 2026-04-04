# Slice-04 테스트 결과서

> 최종 업데이트: 2026-04-05
> 판정: **완료**

## 슬라이스 개요

| 항목 | 내용 |
|------|------|
| 슬라이스 | slice-04 (챌린지 생성 + 초대 코드 참여) |
| 목적 | 챌린지 생성, 초대 코드 기반 미리보기/참여 P0 최소 루프 완성 |
| 관련 Flow | user-flows.md Flow 3 (챌린지 생성), Flow 4-A (초대 참여) |
| P0 여부 | P0 (F-03 챌린지 생성, F-06 챌린지 참여) |

## 구현 범위

### Backend 엔드포인트

| 엔드포인트 | 상태 | 비고 |
|-----------|------|------|
| POST /challenges | 구현 완료 | 201 응답, is_public=false 고정, invite_code 자동 생성 |
| GET /challenges/invite/{code} | 구현 완료 | ChallengeDetail 형식 반환, is_member 포함 |
| POST /challenges/{id}/join | 구현 완료 | 200 응답, challenge_id + joined_at |

### Frontend 화면

| 화면 | 라우트 | 상태 |
|------|--------|------|
| 챌린지 생성 Step 1 (기본 정보) | /create | 구현 완료 |
| 챌린지 생성 Step 2 (규칙 설정) | /create/step2 | 구현 완료 |
| 챌린지 생성 완료 | /create/complete/:id | 구현 완료 |
| 초대 코드 미리보기/참여 | /invite/:code | 구현 완료 |
| 내 페이지 [챌린지 만들기] 버튼 | / | 구현 완료 |

## 테스트 결과

### Backend 테스트

실행 명령: `cd server && uv run pytest tests/test_challenge_create_join.py -v`

| 테스트 | 결과 | 비고 |
|--------|------|------|
| test_create_challenge_happy_path | PASS | 201, 전체 필드, invite_code 8자리, member_count=1 |
| test_create_challenge_invalid_date_range | PASS | 422 INVALID_DATE_RANGE (end < start) |
| test_create_challenge_invalid_date_range_equal | PASS | 422 INVALID_DATE_RANGE (end == start) |
| test_create_challenge_invalid_frequency | PASS | 422 INVALID_FREQUENCY (invalid type) |
| test_create_challenge_weekly_missing_times | PASS | 422 INVALID_FREQUENCY (weekly without times_per_week) |
| test_invite_lookup_happy_path | PASS | 200, ChallengeDetail 형식, is_member 포함 |
| test_invite_lookup_not_member | PASS | 200, is_member=false 확인 |
| test_invite_lookup_invalid_code | PASS | 404 INVALID_INVITE_CODE |
| test_join_happy_path | PASS | 200, challenge_id + joined_at |
| test_join_already_joined | PASS | 409 ALREADY_JOINED |
| test_join_challenge_not_found | PASS | 404 CHALLENGE_NOT_FOUND |
| test_join_challenge_ended | PASS | 400 CHALLENGE_ENDED |

**요약**: 12 passed, 0 failed (전체 backend 50 passed)

### Frontend 테스트

실행 명령: `cd app && flutter test`

| 테스트 | 결과 | 비고 |
|--------|------|------|
| Step1: 카테고리 TextField 존재 | PASS | |
| Step1: 제목 TextField 존재 | PASS | |
| Step1: 설명 TextField 존재 | PASS | |
| Step1: [다음] 버튼 존재 | PASS | |
| Step1: 필수 필드 미입력 유효성 검사 | PASS | |
| Step1: 입력 후 Step2 이동 | PASS | |
| Complete: 초대 코드 표시 | PASS | |
| Complete: [챌린지로 이동] 탭 시 이동 | PASS | |
| InvitePreview: 챌린지 제목 표시 | PASS | |
| InvitePreview: 챌린지 설명 표시 | PASS | |
| InvitePreview: 카테고리 표시 | PASS | |
| InvitePreview: 기간 표시 | PASS | |
| InvitePreview: [참여하기] 버튼 존재 | PASS | |
| InvitePreview: 로딩 시 LoadingWidget | PASS | |

**요약**: 49 passed, 0 failed (slice-04 관련 17개 포함, 전체 49 passed)

### Local Smoke Test

| 항목 | 결과 | 확인 방법 |
|------|------|----------|
| PostgreSQL 접속 | PASS | pg_isready -h localhost -p 5432 |
| Backend health | PASS | curl http://localhost:8000/health → {"status":"ok"} |
| POST /challenges (happy path) | PASS | curl, 201, invite_code 8자리 확인 |
| POST /challenges (INVALID_DATE_RANGE) | PASS | curl, 422 에러 확인 |
| POST /challenges (INVALID_FREQUENCY) | PASS | curl, 422 에러 확인 |
| GET /challenges/invite/{code} (happy path) | PASS | curl, ChallengeDetail 형식 확인 |
| GET /challenges/invite/INVALID (INVALID_INVITE_CODE) | PASS | curl, 404 에러 확인 |
| POST /challenges/{id}/join (happy path) | PASS | curl, challenge_id + joined_at 확인 |
| POST /challenges/{id}/join (ALREADY_JOINED) | PASS | curl, 409 에러 확인 |
| POST /challenges/{id}/join (CHALLENGE_ENDED) | PASS | DB에 completed 챌린지 삽입 후 curl 확인 |
| member_count 증가 확인 | PASS | join 후 GET /challenges/{id}로 member_count=2 확인 |
| Flutter UI 연동 | [미실행] | 브라우저 실행 환경 제한 |

## 확인 구분

### 실제 확인한 것
- Backend pytest 12개 직접 실행 → 12 passed
- Flutter widget test 49개 직접 실행 → 49 passed (17개 신규)
- Docker Postgres + 시드 데이터로 실제 API 11개 시나리오 curl 직접 호출
- spec-keeper 에이전트로 docs 4개 문서 대조 (필드명, 타입, 에러 코드, HTTP status)
- docs-drift-check로 코드↔문서 정합성 점검 (18건 일치, 1건 수정)

### 미확인 / 추정
- Flutter → Backend 실제 연동 (브라우저 실행 불가). 단, ResponseInterceptor의 envelope 파싱이 이전 슬라이스에서 검증됨. provider의 API 호출 경로와 응답 파싱이 api-contract.md와 일치하므로 연동 정상 예상.
- Deep link 기반 초대 링크 진입 (Flutter에서 /invite/:code 라우트 등록됨, 실제 deep link 설정은 플랫폼 레벨 구성 필요)

## 이슈

### Blocking
- 없음

### Non-blocking
- Flutter UI 브라우저 연동 테스트는 수동으로 확인 필요 (환경 제한)
- Deep link 플랫폼 설정 (AndroidManifest.xml, Info.plist)은 slice-04 범위 밖
- 스케줄러 미구현으로 챌린지 status가 자동으로 completed로 변경되지 않음 (domain-model.md §4 챌린지 종료 스케줄러는 별도 슬라이스)

### 이번 점검에서 수정한 항목
| 파일 | 수정 내용 | 근거 |
|------|----------|------|
| server/app/services/challenge_service.py | invite_code 생성 실패 시 에러 코드 VALIDATION_ERROR→INTERNAL_ERROR (HTTP 500) | api-contract.md에 VALIDATION_ERROR는 422 전용, 500은 별도 코드 사용 |

## 에이전트/스킬 활용 내역

| 에이전트/스킬 | 사용 시점 | 결과 |
|-------------|---------|------|
| /slice-planning | 계획 수립 | 3개 엔드포인트 + 5개 화면 + 테스트 계획 완성 |
| spec-keeper | 계획 검증 | 12건 일치, 1건 불일치 수정 (is_member 필드 포함 확인) |
| backend-builder | 백엔드 구현 | 3개 엔드포인트 + 12개 테스트 구현, 전체 50 passed |
| flutter-builder | 프론트엔드 구현 | 4개 화면 + 3개 테스트 파일 구현, 전체 49 passed |
| spec-keeper (drift) | 코드↔문서 정합성 | 18건 일치, 1건 수정 (invite_code 에러 코드) |
| qa-reviewer | 품질 리뷰 | 수행 완료 |

## 판정

- **슬라이스 완료 여부**: 완료
- **다음 슬라이스 진행 가능**: 예
- **사유**: Backend 3개 엔드포인트 + Frontend 5개 화면이 docs 기준 100% 구현. 테스트 전수 통과. Local API smoke test 에러 케이스 포함 11개 시나리오 전수 검증 완료. Spec drift 1건 수정 완료. api-contract.md, domain-model.md, user-flows.md와 정합성 확인 완료.
