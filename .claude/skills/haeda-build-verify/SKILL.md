---
name: haeda-build-verify
description: server/** 변경 후 docker compose 재빌드 + /health 검증을 자동 실행. backend 코드 작성/수정/리팩터 직후, "완료" 주장 직전 반드시 호출. .py 파일 / Dockerfile / requirements.txt / alembic migration 변경 시 발동.
allowed-tools: "Bash Read"
---

# Haeda Build Verify

`server/**` backend 변경을 로컬 docker compose 로 재빌드하고 `/health` 엔드포인트로 살아있는지 확인. `local-build-verification.md` 룰의 자동 실행 짝.

## 발동 조건

- `server/**.py` / `server/Dockerfile` / `server/requirements*.txt` / `server/migrations/**` 변경 직후
- "구현 완료", "테스트 통과" 주장 직전

## 발동하지 않을 조건

- 변경이 `docs/` / `.claude/` / `.env.example` 에만 있음
- 한 줄 주석 / 포맷 변경

## 절차

### 1. 재빌드

```bash
docker compose up --build -d backend
```

빌드 실패 시 출력 마지막 200 줄을 캡처해 사용자에게 보고 후 STOP.

### 2. health check

```bash
sleep 2
curl -fsS http://localhost:8000/health
```

응답 200 + 정상 본문이면 OK.

### 3. 실패 시 진단

```bash
docker compose logs --tail=200 backend
```

마지막 100 줄 캡처해 사용자 보고. 자동 재시도 금지.

### 4. 보고

성공: 한 문단 요약 ("재빌드 OK, /health 200, 응답 본문: ...").
실패: 실패 단계 + 로그 발췌 인용.
