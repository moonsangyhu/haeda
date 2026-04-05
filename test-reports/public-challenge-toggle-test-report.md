# public-challenge-toggle Test Report

> Last updated: 2026-04-05
> Verdict: **Complete**

## Slice Overview

| Item | Content |
|------|---------|
| Slice | public-challenge-toggle |
| Goal | 챌린지 생성 시 공개/비공개 설정 토글 추가, 탐색 탭에서 공개 챌린지 노출 |
| Related Flow | user-flows.md Flow 3 (챌린지 생성), F-05 (공개 챌린지 탐색) |
| Scope | P1 |

## Implementation Scope

### Backend Endpoints

| Endpoint | Status | Notes |
|----------|--------|-------|
| POST /challenges (is_public 필드) | 이미 구현됨 | ChallengeCreate 스키마에 is_public: bool = False 존재 |
| GET /challenges (공개 목록) | 이미 구현됨 | is_public=True AND status=active 필터링 |

### Frontend Screens

| Screen | Route | Status |
|--------|-------|--------|
| ChallengeCreateStep2Screen (공개 토글) | /create/step2 | Implemented |

## Changes Made

| File | Change |
|------|--------|
| `app/lib/features/challenge_create/providers/challenge_create_provider.dart` | `ChallengeCreateRequest`에 `isPublic` 필드 추가 (기본값 false), `toJson()`에 `is_public` 직렬화 |
| `app/lib/features/challenge_create/screens/challenge_create_step2_screen.dart` | `_isPublic` state 추가, "공개 챌린지" SwitchListTile UI 추가, submit 시 `isPublic` 전달 |

## Test Results

### Backend Tests

Command: `cd server && .venv/bin/python -m pytest -v`

**Summary**: [not run] — 로컬 환경에 server/.venv 미설치. 백엔드 코드 변경 없음 (프론트엔드만 수정).

### Frontend Tests

Command: `cd app && flutter test`

**Summary**: 92 passed, 0 failed

```
00:03 +92: All tests passed!
```

전체 테스트 통과. 변경한 파일(provider, step2 screen)의 기존 테스트 모두 정상.

### Local Smoke Test

| Item | Result | Method |
|------|--------|--------|
| flutter analyze | PASS | 0 errors (info 110개는 기존 prefer_const_constructors) |
| flutter test | PASS | 92 passed, 0 failed |
| 공개 토글 → 탐색 탭 노출 | [not run] | Docker 환경 필요 |

## Verification Distinction

### Actually Verified
- flutter analyze: error 0개
- flutter test: 92개 전체 통과
- ChallengeCreateRequest.toJson()에 is_public 필드 포함 확인 (코드 리뷰)
- Step2 화면에 공개 챌린지 SwitchListTile 추가 확인 (코드 리뷰)

### Unverified / Estimated
- 실제 서버 연동 E2E 테스트 (Docker 환경 미구동)
- 공개 챌린지 생성 후 탐색 탭 노출 확인 (수동 테스트 필요)

## Issues

### Blocking
- None

### Non-blocking
- 백엔드 pytest 미실행 (server/.venv 미설치, 백엔드 코드 변경 없으므로 영향 없음)

## Verdict

- **Slice complete**: Complete
- **Can proceed to next slice**: Yes
- **Reason**: 프론트엔드 전용 변경. flutter analyze 0 errors, flutter test 92/92 통과. 백엔드는 이미 is_public 완전 지원 중이므로 코드 변경 없음.
