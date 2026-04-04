---
name: local
description: 로컬 개발 환경(DB, Backend, Frontend)을 한 번에 기동/중지/상태확인한다. docs/local-dev.md 기준.
allowed-tools: "Bash Read Glob Grep"
argument-hint: "[stop|status]"
---

# 로컬 개발 환경 관리

`docs/local-dev.md`를 source of truth로 삼아 로컬 개발 스택을 관리한다.

## 서브커맨드 분기

- 인자 없음 또는 `up` → **기동 (Start)**
- `stop` → **중지 (Stop)**
- `status` → **상태 확인 (Status)**

인자: `$ARGUMENTS`

---

## 공통: 상태 파일

로그와 PID는 프로젝트 루트 `.local-dev/` 디렉토리에 저장한다.
- `.local-dev/backend.pid` — uvicorn PID
- `.local-dev/backend.log` — uvicorn 로그
- `.local-dev/flutter.pid` — flutter PID
- `.local-dev/flutter.log` — flutter 로그

`.local-dev/`는 `.gitignore`에 포함되어 있어야 한다. 없으면 추가한다.

---

## Start (기동)

순서대로 실행한다. 각 단계에서 실패하면 즉시 멈추고 사용자에게 실패 원인과 수동 복구 명령을 안내한다.

### Step 0: 전제조건 확인

아래 명령을 **병렬로** 실행하여 도구 존재 여부를 확인한다:

```bash
docker --version
uv --version
flutter --version
```

하나라도 없으면 실패 → 설치 방법 안내 후 중단.

`.local-dev/` 디렉토리가 없으면 생성한다:
```bash
mkdir -p .local-dev
```

`.gitignore`에 `.local-dev/`가 없으면 추가한다.

### Step 1: PostgreSQL

먼저 이미 떠 있는지 확인한다:
```bash
pg_isready -h localhost -p 5432
```

- "accepting connections" → 이미 기동됨, 스킵
- 그 외 → 기동:
  ```bash
  docker compose up -d db
  ```
  기동 후 최대 15초간 `pg_isready`를 3초 간격으로 재확인한다.
  15초 후에도 실패하면 중단.

### Step 2: Backend

#### 2-1. 이미 떠 있는지 확인
```bash
curl -s --max-time 3 http://localhost:8000/health
```

`{"status":"ok"}` 응답이 오면 → 이미 기동됨, Step 3으로 스킵.

#### 2-2. 의존성 설치
```bash
cd server && uv sync --extra dev
```

#### 2-3. 마이그레이션
```bash
cd server && uv run alembic upgrade head
```

#### 2-4. 시드 데이터
시드가 이미 있는지 확인하기 어려우므로, seed.py가 존재하면 실행한다 (seed.py는 멱등이어야 한다):
```bash
cd server && uv run python seed.py
```

seed.py가 없으면 스킵.

#### 2-5. 서버 기동 (백그라운드)

**중요**: Bash tool의 `run_in_background` 옵션을 사용하여 백그라운드로 실행한다.

```bash
cd server && uv run uvicorn app.main:app --reload --port 8000 > ../.local-dev/backend.log 2>&1 &
echo $! > ../.local-dev/backend.pid
```

기동 후 최대 10초간 health check를 재시도한다:
```bash
curl -s --max-time 2 http://localhost:8000/health
```

### Step 3: Frontend

#### 3-1. 이미 떠 있는지 확인

`.local-dev/flutter.pid` 파일이 있고 해당 PID 프로세스가 살아있으면 스킵.

#### 3-2. 의존성 설치
```bash
cd app && flutter pub get
```

#### 3-3. 플랫폼 디렉토리 확인
`app/web/` 디렉토리가 없으면:
```bash
cd app && flutter create --platforms=web --project-name haeda .
```

#### 3-4. 코드 생성 (build_runner)
```bash
cd app && dart run build_runner build --delete-conflicting-outputs
```

#### 3-5. Flutter 웹 서버 기동 (백그라운드)

**중요**: `flutter run -d chrome`은 인터랙티브하므로, 대신 빌드 후 간단한 웹서버를 쓰거나 `flutter run -d web-server`를 사용한다:

```bash
cd app && flutter run -d web-server --web-port=3000 > ../.local-dev/flutter.log 2>&1 &
echo $! > ../.local-dev/flutter.pid
```

`flutter run -d web-server`가 실패하면, 빌드만 하고 URL을 안내한다:
```bash
cd app && flutter build web --no-tree-shake-icons
```
이 경우 사용자에게 `cd app && flutter run -d chrome`을 별도 터미널에서 실행하라고 안내.

### Step 4: 최종 요약

아래 형식으로 결과를 출력한다:

```
## 로컬 개발 환경 기동 결과

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

### 다음 단계
- 브라우저에서 http://localhost:3000 을 열어 확인하세요.
- 중지: `/local stop`
- 상태 확인: `/local status`
```

실패한 단계가 있으면 해당 행을 ❌로 표시하고, 수동 복구 명령을 안내한다.

---

## Stop (중지)

역순으로 중지한다.

### Flutter 중지
```bash
if [ -f .local-dev/flutter.pid ]; then
  kill $(cat .local-dev/flutter.pid) 2>/dev/null
  rm .local-dev/flutter.pid
fi
```

### Backend 중지
```bash
if [ -f .local-dev/backend.pid ]; then
  kill $(cat .local-dev/backend.pid) 2>/dev/null
  rm .local-dev/backend.pid
fi
```

포트로 프로세스 찾기 (PID 파일이 없는 경우):
```bash
lsof -ti:8000 | xargs kill 2>/dev/null
lsof -ti:3000 | xargs kill 2>/dev/null
```

### DB 중지
```bash
docker compose down
```

중지 후 상태를 요약한다.

---

## Status (상태 확인)

각 서비스 상태를 확인하여 테이블로 출력한다.

```bash
# PostgreSQL
pg_isready -h localhost -p 5432

# Backend
curl -s --max-time 3 http://localhost:8000/health

# Frontend (PID 또는 포트 확인)
lsof -ti:3000
```

출력 형식:
```
## 로컬 개발 환경 상태

| 서비스 | 상태 | PID | URL |
|--------|------|-----|-----|
| PostgreSQL | ✅/❌ | - | localhost:5432 |
| Backend | ✅/❌ | {pid} | http://localhost:8000 |
| Frontend | ✅/❌ | {pid} | http://localhost:3000 |
```

---

## 주의사항

- Chrome 자동 실행은 환경에 따라 불가능할 수 있다. URL을 명확히 출력하고 사용자가 직접 여는 것을 기본으로 한다.
- `flutter run -d web-server`가 지원되지 않는 Flutter 버전이면, `flutter run -d chrome`을 별도 터미널에서 실행하라고 안내한다.
- seed.py 실행 시 이미 데이터가 있으면 에러가 날 수 있다. 에러가 "already exists" 류이면 무시하고 진행한다.
- 모든 로그는 `.local-dev/*.log`에서 확인 가능하다고 안내한다.
