---
name: fastapi-mvp
description: FastAPI MVP 구현 규칙 (REST naming, 응답 envelope, validation, auth, error format)
---

# FastAPI MVP 규칙

## 디렉토리 구조

```
server/
├── app/
│   ├── main.py                 # FastAPI app, 미들웨어, 라우터 등록
│   ├── config.py               # 환경변수 설정 (pydantic-settings)
│   ├── database.py             # async SQLAlchemy engine + session
│   ├── models/                 # SQLAlchemy ORM 모델
│   ├── schemas/                # Pydantic v2 요청/응답 스키마
│   ├── routers/                # APIRouter 모듈 (auth, challenges, verifications, comments, me)
│   ├── services/               # 비즈니스 로직
│   ├── dependencies.py         # 공통 의존성 (get_db, get_current_user)
│   └── exceptions.py           # 커스텀 예외 + 핸들러
├── alembic/                    # DB 마이그레이션
├── tests/
└── pyproject.toml
```

## REST Naming

- Base: `/api/v1`
- 리소스 복수형: `/challenges`, `/verifications`, `/comments`
- 하위 리소스: `/challenges/{id}/verifications`, `/verifications/{id}/comments`
- 행위: `/challenges/{id}/join` (POST)
- 내 것: `/me/challenges`

## 응답 Envelope

```python
# 성공
{"data": { ... }}

# 에러
{"error": {"code": "CHALLENGE_NOT_FOUND", "message": "챌린지를 찾을 수 없습니다."}}
```

성공 응답은 항상 `data` 키로 감싼다. 리스트도 `{"data": {"challenges": [...], "next_cursor": ...}}`.

## 에러 코드

대문자 스네이크케이스. `api-contract.md`에 정의된 코드만 사용:

- 401: `UNAUTHORIZED`
- 403: `FORBIDDEN`
- 404: `CHALLENGE_NOT_FOUND`, `VERIFICATION_NOT_FOUND`, `INVALID_INVITE_CODE`
- 409: `ALREADY_JOINED`, `ALREADY_VERIFIED_TODAY`
- 422: `VALIDATION_ERROR`, `INVALID_DATE_RANGE`, `INVALID_FREQUENCY`, `PHOTO_REQUIRED`, `NICKNAME_TOO_SHORT`, `NICKNAME_TOO_LONG`, `COMMENT_TOO_LONG`
- 400: `CHALLENGE_ENDED`, `CHALLENGE_NOT_COMPLETED`, `NOT_A_MEMBER`

## 인증 (Auth)

- `POST /auth/kakao`는 카카오 access_token을 받아 서버 사이드 검증 후 JWT 발급
- 이후 모든 요청: `Authorization: Bearer <jwt>`
- 미들웨어/의존성에서 토큰 디코드 → `request.state.user_id` 설정

## Validation

- Pydantic v2 모델로 요청 바디 검증
- 실패 시 422 + `VALIDATION_ERROR`
- 파일 업로드: multipart/form-data, 이미지 10MB 제한, JPEG/PNG만

## 비즈니스 로직 참조

달성률 계산, 전원 인증 판정, 챌린지 종료 스케줄러 로직은 `docs/domain-model.md` §4를 따른다.

## DB

- SQLAlchemy 2.0 async (asyncpg)
- 테이블명: snake_case 복수형 (users, challenges, challenge_members, verifications, day_completions, comments)
- UUID PK, TIMESTAMPTZ for timestamps
- 마이그레이션: Alembic
