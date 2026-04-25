---
name: fastapi-mvp
description: FastAPI MVP implementation rules (REST naming, response envelope, validation, auth, error format)
---

# FastAPI MVP Rules

## Directory Structure

```
server/
├── app/
│   ├── main.py                 # FastAPI app, middleware, router registration
│   ├── config.py               # environment variable config (pydantic-settings)
│   ├── database.py             # async SQLAlchemy engine + session
│   ├── models/                 # SQLAlchemy ORM models
│   ├── schemas/                # Pydantic v2 request/response schemas
│   ├── routers/                # APIRouter modules (auth, challenges, verifications, comments, me)
│   ├── services/               # business logic
│   ├── dependencies.py         # common dependencies (get_db, get_current_user)
│   └── exceptions.py           # custom exceptions + handlers
├── alembic/                    # DB migrations
├── tests/
└── pyproject.toml
```

## REST Naming

- Base: `/api/v1`
- Plural resources: `/challenges`, `/verifications`, `/comments`
- Sub-resources: `/challenges/{id}/verifications`, `/verifications/{id}/comments`
- Actions: `/challenges/{id}/join` (POST)
- My resources: `/me/challenges`

## Response Envelope

```python
# Success
{"data": { ... }}

# Error
{"error": {"code": "CHALLENGE_NOT_FOUND", "message": "Challenge not found."}}
```

Success responses are always wrapped with `data` key. Lists too: `{"data": {"challenges": [...], "next_cursor": ...}}`.

## Error Codes

UPPER_SNAKE_CASE. Use only codes defined in `api-contract.md`:

- 401: `UNAUTHORIZED`
- 403: `FORBIDDEN`
- 404: `CHALLENGE_NOT_FOUND`, `VERIFICATION_NOT_FOUND`, `INVALID_INVITE_CODE`
- 409: `ALREADY_JOINED`, `ALREADY_VERIFIED_TODAY`
- 422: `VALIDATION_ERROR`, `INVALID_DATE_RANGE`, `INVALID_FREQUENCY`, `PHOTO_REQUIRED`, `NICKNAME_TOO_SHORT`, `NICKNAME_TOO_LONG`, `COMMENT_TOO_LONG`
- 400: `CHALLENGE_ENDED`, `CHALLENGE_NOT_COMPLETED`, `NOT_A_MEMBER`

## Auth

- `POST /auth/kakao` receives Kakao access_token, verifies server-side, issues JWT
- All subsequent requests: `Authorization: Bearer <jwt>`
- Middleware/dependency decodes token -> sets `request.state.user_id`

## Validation

- Pydantic v2 models for request body validation
- Failure returns 422 + `VALIDATION_ERROR`
- File upload: multipart/form-data, 10MB image limit, JPEG/PNG only

## Business Logic Reference

Achievement rate calculation, all-verified check, and challenge completion scheduler logic follow `docs/domain-model.md` §4.

## DB

- SQLAlchemy 2.0 async (asyncpg)
- Table names: snake_case plural (users, challenges, challenge_members, verifications, day_completions, comments)
- UUID PK, TIMESTAMPTZ for timestamps
- Migrations: Alembic

## Test Requirements (MANDATORY)

기능을 구현하는 모든 PR 은 대응 테스트 없이 완료로 간주하지 않는다.

- **엔드포인트**: 신규 또는 시그니처가 바뀐 엔드포인트마다 `server/tests/` 아래에 pytest + `httpx.AsyncClient` 기반 테스트 **최소 2건** — happy path 1건, 대표 error path 1건 (검증 실패, 권한, 404 등 중 하나).
- **서비스 로직**: 주요 비즈니스 로직 (성취율 계산, all-verified 체크, 챌린지 완료 스케줄러 등) 은 라우터 테스트와 별개로 unit 테스트.
- **픽스처 재사용**: 기존 `server/tests/conftest.py` 의 `async_client`, `test_user`, `test_challenge` 등 픽스처를 최대한 재사용한다. 테스트 DB 셋업은 기존 컨벤션을 따른다.
- **검증 기준**: `cd server && uv run pytest -v --tb=short` 전원 통과. 신규 코드 경로가 한 번도 실행되지 않으면 통과로 인정하지 않는다.

테스트는 `superpowers:test-driven-development` 사이클로 작성하고, `superpowers:verification-before-completion` 으로 결과를 인용해 보고한다.
