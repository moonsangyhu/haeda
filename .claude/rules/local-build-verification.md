# Local Build Verification

`server/**` 코드를 변경한 모든 작업은 **로컬 컨테이너 재빌드 + health check** 로 마무리한다. 코드 작성·커밋·푸시 후가 아니라, "완료" 주장 직전 반드시 실행한다.

## 의무 시점

- `server/**.py` / `server/Dockerfile` / `server/requirements*.txt` / `server/migrations/**` 변경 직후
- backend 관련 변경을 포함한 PR 생성 전

## 절차

```bash
docker compose up --build -d backend
sleep 2
curl -fsS http://localhost:8000/health
```

응답 200 + 정상 본문이면 OK. 실패 시 STOP, 로그 확인:

```bash
docker compose logs --tail=200 backend
```

## 면제

- 변경 범위가 `.env.example`, `docs/`, `.claude/` 만인 경우
- 컴파일 영향 없는 한 줄 주석 / 포맷 변경

## 자동 발동

`.claude/skills/haeda-build-verify/SKILL.md` 가 description 트리거로 자동 실행한다.
