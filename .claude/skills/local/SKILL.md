---
name: local
description: 로컬 개발 환경(DB, Backend, Frontend)을 docker compose로 한 번에 기동/중지/상태확인한다.
allowed-tools: "Bash Read Glob Grep"
argument-hint: "[stop|status|reset|rebuild|rebuild backend|rebuild frontend]"
---

# 로컬 개발 환경 관리 (Container-First)

`docker compose`로 전체 스택(DB + Backend + Frontend)을 관리한다.

## 서브커맨드 분기

- 인자 없음 또는 `up` → **기동 (Start)**
- `stop` → **중지 (Stop)**
- `status` → **상태 확인 (Status)**
- `reset` → **초기화 (Reset)** — 볼륨 삭제 후 재기동
- `rebuild` → **재빌드 (Rebuild)** — 변경된 코드 반영하여 재빌드+재기동
- `rebuild backend` → backend만 재빌드
- `rebuild frontend` → frontend만 재빌드

인자: `$ARGUMENTS`

---

## Start (기동)

### Step 1: 전제조건 확인

```bash
docker --version
docker compose version
```

하나라도 없으면 실패 → Docker Desktop 설치 안내 후 중단.

### Step 2: docker compose up

```bash
cd /Users/moonsang.yhu/Documents/haeda && docker compose up --build -d
```

이 명령 하나로:
1. PostgreSQL 기동 + healthcheck 대기
2. Backend 이미지 빌드 → migration → seed → uvicorn 기동
3. Frontend 이미지 빌드 (Flutter web build + nginx) → 서빙 시작

**중요**: 빌드는 시간이 걸릴 수 있다. 특히 최초 빌드 시 Flutter SDK 다운로드가 포함된다.
Bash tool의 timeout을 600000 (10분)으로 설정한다.

### Step 3: 기동 확인

빌드 완료 후 health check를 실행한다:

```bash
# DB
pg_isready -h localhost -p 5432

# Backend
curl -s --max-time 10 http://localhost:8000/health

# Frontend
curl -s --max-time 5 -o /dev/null -w "%{http_code}" http://localhost:3000
```

### Step 4: 최종 요약

```
## 로컬 개발 환경 기동 결과 (Container-First)

| 서비스 | 상태 | URL |
|--------|------|-----|
| PostgreSQL | ✅ 기동됨 | localhost:5432 |
| Backend | ✅ 기동됨 | http://localhost:8000 |
| Frontend | ✅ 기동됨 | http://localhost:3000 |

### 확인 포인트
- Swagger UI: http://localhost:8000/docs
- Flutter 앱: http://localhost:3000
- Health: http://localhost:8000/health

### 테스트 계정
| 사용자 | Bearer Token |
|--------|-------------|
| 김철수 | 11111111-1111-1111-1111-111111111111 |
| 이영희 | 22222222-2222-2222-2222-222222222222 |
| 박지민 | 33333333-3333-3333-3333-333333333333 |

### 명령어
- 중지: `/local stop`
- 상태: `/local status`
- 초기화 (데이터 삭제 후 재기동): `/local reset`
- 로그: `docker compose logs -f [backend|frontend|db]`
```

실패한 서비스가 있으면 ❌로 표시하고 `docker compose logs <서비스>` 명령을 안내한다.

---

## Stop (중지)

```bash
cd /Users/moonsang.yhu/Documents/haeda && docker compose down
```

중지 후 상태를 요약한다. 데이터는 볼륨에 보존된다.

---

## Status (상태 확인)

```bash
# 컨테이너 상태
docker compose ps

# 개별 health check
pg_isready -h localhost -p 5432 2>&1
curl -s --max-time 3 http://localhost:8000/health 2>&1
curl -s --max-time 3 -o /dev/null -w "%{http_code}" http://localhost:3000 2>&1
```

출력 형식:
```
## 로컬 개발 환경 상태

| 서비스 | 컨테이너 | 상태 | URL |
|--------|----------|------|-----|
| PostgreSQL | haeda-db-1 | ✅/❌ | localhost:5432 |
| Backend | haeda-backend-1 | ✅/❌ | http://localhost:8000 |
| Frontend | haeda-frontend-1 | ✅/❌ | http://localhost:3000 |
```

---

## Reset (초기화)

볼륨을 삭제하고 재기동한다. DB 데이터가 모두 삭제된다.

```bash
cd /Users/moonsang.yhu/Documents/haeda && docker compose down -v && docker compose up --build -d
```

---

## Rebuild (재빌드)

슬라이스 구현 후 변경사항을 컨테이너에 반영한다. DB 데이터는 유지된다.

### 인자 파싱

- `rebuild` → 전체 재빌드 (backend + frontend)
- `rebuild backend` → backend만 재빌드
- `rebuild frontend` → frontend만 재빌드

### 실행

**전체 재빌드:**
```bash
cd /Users/moonsang.yhu/Documents/haeda && docker compose up --build -d backend frontend
```

**backend만:**
```bash
cd /Users/moonsang.yhu/Documents/haeda && docker compose up --build -d backend
```

**frontend만:**
```bash
cd /Users/moonsang.yhu/Documents/haeda && docker compose up --build -d frontend
```

Bash tool의 timeout을 600000 (10분)으로 설정한다. (frontend 빌드가 느릴 수 있음)

### 기동 확인

재빌드 대상 서비스의 health check를 실행한다:

```bash
# backend 재빌드 시
curl -s --max-time 10 http://localhost:8000/health

# frontend 재빌드 시
curl -s --max-time 5 -o /dev/null -w "%{http_code}" http://localhost:3000
```

### 출력

```
## 재빌드 결과

| 서비스 | 상태 | 소요 시간 |
|--------|------|-----------|
| Backend | ✅ 재빌드 완료 | ~Ns |
| Frontend | ✅ 재빌드 완료 | ~Ns |

브라우저에서 http://localhost:3000 을 새로고침하세요.
```

---

## 주의사항

- 최초 빌드는 Flutter SDK 다운로드로 10분 이상 걸릴 수 있다. 이후 빌드는 Docker 캐시로 빠르다.
- Frontend 변경 후 반영: `docker compose up --build -d frontend`
- Backend 변경 후 반영: `docker compose up --build -d backend`
- DB 데이터 초기화: `/local reset`
- 로그 확인: `docker compose logs -f backend`
