---
name: smoke-test
description: 로컬 개발 환경 smoke test. Docker Postgres, FastAPI 백엔드, Flutter 웹을 순서대로 확인한다. 슬라이스 구현 후 통합 동작을 검증하거나, "smoke test 해줘"라고 요청받았을 때 사용한다.
allowed-tools: "Bash Read Glob Grep"
---

# 로컬 Smoke Test

로컬 개발 환경에서 전체 스택이 정상 동작하는지 순서대로 확인한다.
`docs/local-dev.md`의 실행 순서를 따른다.

## 사용법

```
/smoke-test              # 전체 스택 점검
/smoke-test backend      # 백엔드만 점검
/smoke-test frontend     # 프론트엔드만 점검
```

## 절대 원칙

- 실제 명령을 실행하고 실제 응답을 확인한다. 성공을 가정하거나 추측하지 않는다.
- 각 단계의 성공 조건이 충족되지 않으면 즉시 실패로 보고한다.
- 이전 단계가 실패하면 다음 단계로 진행하지 않는다.
- 서비스를 새로 시작하지 않는다 — 이미 실행 중인 서비스를 확인만 한다.
  (서비스가 꺼져 있으면 실패로 보고하고 시작 명령을 안내한다)

## 점검 순서

### Step 1: PostgreSQL

```bash
pg_isready -h localhost -p 5432
```

- 성공 조건: "accepting connections" 출력
- 실패 시: `docker compose up -d db` 안내

### Step 2: Backend Health

```bash
curl -s http://localhost:8000/health
```

- 성공 조건: `{"status":"ok"}` 응답
- 실패 시: `cd server && uv run uvicorn app.main:app --reload --port 8000` 안내

### Step 3: API 기본 동작

테스트 사용자(김철수)로 API 호출:

```bash
curl -s -H "Authorization: Bearer 11111111-1111-1111-1111-111111111111" \
  http://localhost:8000/api/v1/me/challenges
```

- 성공 조건: HTTP 200 + `{"data": ...}` 응답
- 실패 시: 시드 데이터 확인 → `cd server && uv run python seed.py` 안내

### Step 4: Backend 테스트

```bash
cd server && uv run pytest -v --tb=short
```

- 성공 조건: 모든 테스트 통과
- 실패 시: 실패한 테스트 목록 보고

### Step 5: Flutter 빌드 확인

```bash
cd app && flutter pub get && flutter build web --no-tree-shake-icons
```

- 성공 조건: 빌드 성공 (exit code 0)
- 실패 시: 빌드 에러 보고

### Step 6: Flutter 테스트

```bash
cd app && flutter test
```

- 성공 조건: 모든 테스트 통과
- 실패 시: 실패한 테스트 목록 보고

## 출력 형식

```
## Smoke Test 결과

### 환경
- PostgreSQL: ✅/❌
- Backend: ✅/❌
- API: ✅/❌
- Backend 테스트: ✅/❌ (N passed, M failed)
- Flutter 빌드: ✅/❌
- Flutter 테스트: ✅/❌ (N passed, M failed)

### 전체 결과: PASS / FAIL

### 실패 항목 (있을 경우)
- (실패 단계 + 에러 메시지 + 해결 방법)
```
