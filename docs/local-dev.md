# Local Development Guide

## 사전 요구사항

| 도구 | 버전 | 확인 커맨드 |
|------|------|------------|
| Docker | 20+ | `docker --version` |
| Docker Compose | v2+ | `docker compose version` |

> Backend/Frontend 빌드는 컨테이너 안에서 수행되므로 호스트에 Python, Flutter 설치가 불필요하다.

## 빠른 시작 (Quick Start)

```bash
# 전체 스택 기동 (DB + Backend + Frontend)
docker compose up --build -d

# 확인
curl http://localhost:8000/health   # → {"status":"ok"}
open http://localhost:3000          # Flutter 웹앱
```

최초 빌드는 Flutter SDK 다운로드로 10분 이상 걸릴 수 있다. 이후 빌드는 Docker 캐시 덕분에 빠르다.

## 서비스 구성

| 서비스 | 컨테이너 | 포트 | 설명 |
|--------|----------|------|------|
| db | postgres:16-alpine | 5432 | PostgreSQL |
| backend | server/Dockerfile | 8000 | FastAPI (migration + seed 자동 실행) |
| frontend | app/Dockerfile | 3000 | Flutter web (nginx 정적 서빙) |

### 기동 순서 (docker compose가 자동 관리)

1. **db** — PostgreSQL 기동, healthcheck 통과 대기
2. **backend** — DB ready 후 기동. entrypoint에서:
   - `alembic upgrade head` (마이그레이션)
   - `python seed.py` (시드 데이터 — 멱등)
   - `uvicorn` 서버 시작
3. **frontend** — backend healthy 후 기동. nginx가 Flutter web build 결과를 서빙

## 테스트 계정

시드 데이터가 생성하는 테스트 계정:

| 사용자 | Bearer Token (UUID) |
|--------|-------------------|
| 김철수 | `11111111-1111-1111-1111-111111111111` |
| 이영희 | `22222222-2222-2222-2222-222222222222` |
| 박지민 | `33333333-3333-3333-3333-333333333333` |

## 확인 포인트

- Flutter 앱: http://localhost:3000
- Swagger UI: http://localhost:8000/docs
- Health: http://localhost:8000/health
- API 테스트:
  ```bash
  curl -H "Authorization: Bearer 11111111-1111-1111-1111-111111111111" \
    http://localhost:8000/api/v1/me/challenges
  ```

## 일상 명령어

```bash
# 기동
docker compose up --build -d

# 중지 (데이터 보존)
docker compose down

# 초기화 (데이터 삭제 후 재기동)
docker compose down -v
docker compose up --build -d

# 특정 서비스만 재빌드
docker compose up --build -d backend
docker compose up --build -d frontend

# 로그 확인
docker compose logs -f backend
docker compose logs -f frontend

# 컨테이너 상태
docker compose ps
```

## Claude Code에서 사용

```
/local          # docker compose up --build -d + 상태 확인
/local stop     # docker compose down
/local status   # 서비스 상태 확인
/local reset    # 볼륨 삭제 후 재기동
```

## 호스트에서 직접 개발 (선택)

컨테이너 없이 호스트에서 직접 실행하려면 아래 도구가 추가로 필요하다:

| 도구 | 버전 | 확인 커맨드 |
|------|------|------------|
| uv | 0.4+ | `uv --version` |
| Python | 3.11+ | `python3 --version` |
| Flutter | 3.16+ | `flutter --version` |

```bash
# DB만 Docker로 기동
docker compose up -d db

# Backend
cd server && uv sync --extra dev && uv run alembic upgrade head && uv run python seed.py
uv run uvicorn app.main:app --reload --port 8000

# Frontend (별도 터미널)
cd app && flutter pub get && dart run build_runner build --delete-conflicting-outputs
flutter run -d chrome
```

## 환경 변수

컨테이너 환경변수는 `docker-compose.yml`에서 관리한다. 호스트 직접 실행 시 `server/.env` 참고.

| 변수 | 컨테이너 기본값 | 호스트 기본값 | 설명 |
|------|----------------|--------------|------|
| `DATABASE_URL` | `...@db:5432/haeda` | `...@localhost:5432/haeda` | DB 접속 (컨테이너 내부는 `db` 호스트명 사용) |
| `SECRET_KEY` | `dev-secret-key` | `dev-secret-key` | JWT 서명 (현재 미사용) |

## 자주 막히는 지점

| 증상 | 원인 | 해결 |
|------|------|------|
| 빌드가 10분 이상 걸림 | 최초 Flutter SDK 다운로드 | 정상. 이후 빌드는 캐시로 빠름 |
| backend 시작 실패 | DB 아직 미준비 | `docker compose logs backend`로 확인. healthcheck가 자동 재시도 |
| CORS 에러 (브라우저) | backend 미기동 | `docker compose ps`로 상태 확인 |
| 포트 충돌 | 기존 프로세스 점유 | `lsof -ti:8000 \| xargs kill` 후 재기동 |
| seed 에러 | 이미 실행됨 | seed.py는 멱등 (DELETE 후 INSERT). 에러 무시 가능 |
| 데이터 초기화 | 볼륨에 데이터 남음 | `docker compose down -v` 후 재기동 |

## 테스트 실행 (호스트)

테스트는 호스트에서 실행한다 (SQLite in-memory 사용, DB 불필요):

```bash
# Backend 테스트
cd server && uv run pytest -v

# Frontend 테스트
cd app && flutter test
```
