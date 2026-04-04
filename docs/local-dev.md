# Local Development Guide

## 사전 요구사항

| 도구 | 버전 | 확인 커맨드 |
|------|------|------------|
| Docker | 20+ | `docker --version` |
| uv | 0.4+ | `uv --version` |
| Python | 3.11+ | `python3 --version` |
| Flutter | 3.16+ | `flutter --version` |

## 빠른 시작 (Quick Start)

```bash
# 1. DB 기동
docker compose up -d db
# 확인: pg_isready -h localhost -p 5432

# 2. Backend 설정 & 실행
cd server
uv sync --extra dev          # 의존성 설치
uv run alembic upgrade head  # 마이그레이션
uv run python seed.py        # 테스트 데이터
uv run uvicorn app.main:app --reload --port 8000
# 확인: curl http://localhost:8000/health → {"status":"ok"}

# 3. Frontend 실행 (새 터미널)
cd app
flutter pub get
flutter run -d chrome        # 또는 -d macos
```

## 상세 안내

### 1. PostgreSQL (Docker)

```bash
# 루트 디렉토리에서
docker compose up -d db

# 상태 확인
pg_isready -h localhost -p 5432
# → "accepting connections"

# DB 직접 접속 (디버깅용)
psql -h localhost -U postgres -d haeda
# 비밀번호: postgres

# 종료
docker compose down          # 데이터 유지
docker compose down -v       # 데이터 삭제
```

기본 접속 정보 (`server/.env.example` 참고):
- Host: `localhost:5432`
- User/Password: `postgres` / `postgres`
- Database: `haeda`

### 2. Backend (FastAPI)

```bash
cd server

# 의존성 설치 (dev 포함)
uv sync --extra dev

# 마이그레이션 적용
uv run alembic upgrade head

# 시드 데이터 삽입
uv run python seed.py
```

시드 데이터가 만드는 테스트 계정:

| 사용자 | Bearer Token (UUID) |
|--------|-------------------|
| 김철수 | `11111111-1111-1111-1111-111111111111` |
| 이영희 | `22222222-2222-2222-2222-222222222222` |
| 박지민 | `33333333-3333-3333-3333-333333333333` |

서버 실행:
```bash
uv run uvicorn app.main:app --reload --port 8000
```

확인 포인트:
- `http://localhost:8000/health` → `{"status":"ok"}`
- `http://localhost:8000/docs` → Swagger UI
- API 테스트:
  ```bash
  curl -H "Authorization: Bearer 11111111-1111-1111-1111-111111111111" \
    http://localhost:8000/api/v1/me/challenges
  ```

테스트 실행:
```bash
uv run pytest -v   # SQLite in-memory, DB 불필요
```

### 3. Frontend (Flutter)

```bash
cd app
flutter pub get

# 플랫폼 디렉토리가 없으면 생성
# (web/, macos/ 가 없는 경우)
flutter create --platforms=web,macos --project-name haeda .

# 코드 생성 (freezed, json_serializable)
flutter pub run build_runner build --delete-conflicting-outputs

# 실행
flutter run -d chrome   # 웹 (가장 쉬움)
flutter run -d macos    # macOS 데스크톱

# 테스트
flutter test
```

> **참고**: Flutter 앱은 `http://localhost:8000/api/v1`을 바라봅니다.
> 백엔드가 실행 중이어야 데이터가 표시됩니다.

> **인증**: 현재 dev stub으로, Bearer token에 사용자 UUID를 직접 넣는 방식입니다.
> Flutter 앱은 자동으로 `11111111-...-111111111111` (김철수) 토큰을 사용합니다.

### 4. 전체 실행 순서 요약

```
1. docker compose up -d db       # PostgreSQL
2. cd server && uv sync --extra dev && uv run alembic upgrade head && uv run python seed.py
3. uv run uvicorn app.main:app --reload --port 8000   # 터미널 1
4. cd ../app && flutter pub get && flutter run -d chrome   # 터미널 2
```

## 자주 막히는 지점

| 증상 | 원인 | 해결 |
|------|------|------|
| `pg_isready` no response | PostgreSQL 미기동 | `docker compose up -d db` |
| `uv sync` hatchling 에러 | `pyproject.toml`에 wheel packages 미지정 | `[tool.hatch.build.targets.wheel]` 섹션 확인 |
| `flutter create` 필요 | web/macos 디렉토리 없음 | `flutter create --platforms=web,macos --project-name haeda .` |
| CHALLENGE_ENDED 에러 | 시드 챌린지 기간 만료 (2026-03-05~04-03) | 시드 날짜를 수정하거나, 기간 내 날짜로 테스트 |
| CORS 에러 (브라우저) | 서버 미실행 | 백엔드 먼저 실행 확인 |

## 환경 변수

서버는 `server/.env` 파일을 읽습니다 (없으면 기본값 사용).
`server/.env.example`을 참고하세요.

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `DATABASE_URL` | `postgresql+asyncpg://postgres:postgres@localhost:5432/haeda` | DB 접속 |
| `SECRET_KEY` | `dev-secret-key` | JWT 서명 (현재 미사용) |
