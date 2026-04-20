---
name: systematic-debugging
description: 체계적 4단계 근본 원인 조사 프로토콜. 재현→가설→증거→수정. "증상 수정은 실패다." debugger 에이전트가 내부적으로 따르며, Main·code-reviewer 등 누구든 재현 불가·에러 상황에서 호출 가능.
---

# Systematic Debugging Skill

버그는 추측으로 고치지 않는다. 재현 → 패턴 분석 → 가설 검증 → 수정 의 4단계를 거친다. 증상을 눌러버리는 수정은 **실패**로 간주한다 (재발이 사실상 확실하기 때문).

이 스킬은 `debugger` 에이전트의 Phase 1~6 과 대응하며, `debugger` 외의 상황 (Main 이 직접 버그를 만졌을 때, code-reviewer 가 수상한 동작을 발견했을 때 등) 에서도 재사용할 수 있도록 독립되어 있다.

## 원칙 (Non-negotiable)

1. **No guessing.** 모든 claim 은 file:line 또는 quoted 출력으로 뒷받침한다.
2. **재현 없으면 고치지 않는다.** Phase 1 에서 실패를 재현할 수 없으면 STOP, 맥락 요청.
3. **증상 ≠ 원인.** null 참조 에러를 `if x is not None` 로 감싸는 것은 증상 수정. 왜 None 이 들어왔는지가 원인.
4. **한 번에 하나의 가설.** 여러 가설을 동시에 수정하지 않는다 — 어느 것이 진짜 원인이었는지 알 수 없게 됨.
5. **증거 기반 수정.** 수정 전 Phase 3 Root Cause Statement 가 증거 체인과 함께 완성되어야 한다.

## Phase 1 — Reproduce (재현)

재현할 수 없으면 디버깅은 시작하지 않는다.

### 1-1. 재현 단계 추출
- Trigger: 사용자 액션, 테스트 이름, API 호출, 크론
- Expected: 원래 기대 동작
- Observed: 실제 실패 (에러 메시지 전체, 잘못된 값, 행업, 크래시)
- Environment: iOS simulator, docker backend, local postgres 등

### 1-2. 기계적으로 재현

| 버그 유형 | 재현 명령 |
|----------|----------|
| Failing backend test | `cd server && uv run pytest <path>::<test_name> -v --tb=long` |
| Failing frontend test | `cd app && flutter test <path>` |
| API 4xx/5xx | `curl -i -H 'Authorization: Bearer ...' http://localhost:8000/<path>` |
| UI bug | Simulator 실행 + 재현 flow 반복 + `flutter logs` 수집 |
| DB constraint violation | `docker compose exec postgres psql -U haeda -d haeda -c '<query>'` |
| Data inconsistency | psql 로 실제 row 상태 확인 |

출력을 그대로 인용한다. 간헐적 버그이면 빈도와 타이밍 상관을 기록.

재현 실패 시 STOP. 가짜 근본 원인을 만들지 않는다.

## Phase 2 — Layer-by-Layer Trace (계층별 추적)

의심이 좁더라도 **모든 층의 기여/비기여를 증거로 확인**한다. 중간층을 무시하면 두 번째 버그가 숨어있다.

| Layer | 경로 | 확인 항목 |
|-------|------|----------|
| Frontend widget/provider | `app/lib/features/**` | 위젯 트리, Riverpod state 흐름, API client 호출, dio 응답 파싱 |
| API router | `server/app/routers/**` | 핸들러, auth dependency, request/response schema |
| Service/business | `server/app/services/**` | 도메인 로직, `docs/domain-model.md` §business rules 대조, 부수효과 나열 |
| Data access | `server/app/models/**` | 컬럼 타입, 관계, 생성된 SQL, N+1 패턴 |
| Database | PostgreSQL | `\d <table>`, 실제 row, constraint, alembic_version vs versions/ |
| Integration | Docker, env vars | `docker compose ps/logs`, 환경변수 (secrets 출력 금지) |

각 층에서 최소 기록:
- 용의 file:line
- 실제 입력/출력 (quoted)
- 기대와의 차이

## Phase 3 — Root Cause Synthesis (근본 원인 정리)

단일 원인 진술문 + 증거 체인을 작성한다.

```
ROOT CAUSE:
{한 문단으로 기전 설명}

Mechanism: {trigger → 관측된 증상까지 어떻게 전파되는지}
Trigger condition: {정확한 입력/상태}
Scope: {영향 받는 요청/사용자/데이터 범위}

Evidence chain:
  1. {layer 1}: {file:line} — {관측}
  2. {layer 2}: {file:line} — {관측}
  ...
  N. {final layer}: {file:line} — {원인을 증명하는 관측}
```

여러 가설이 공존하면 각각의 confidence + 구별할 수 있는 실험을 명시한다. **실험 실행 후** 단일 원인으로 좁힌 뒤 Phase 4 로 간다.

## Phase 4 — Fix Plan (수정 계획)

편집 전에 전체 수정 계획을 작성한다. 계층별로:

```
[Layer]
- File: path/to/file
- Current: {quoted code}
- Change: {무엇을, 왜}
- Side effects: {다른 곳 영향 예상}

Tests to add:
- {path} — {무엇을 단언해 회귀 방지}

Rollback plan:
- {실패 시 원복 방법}

Risks:
- {알려진 우려: 호환성, 성능, 데이터 이동}
```

계획 없이 편집 금지.

## Phase 5 — Execute (수정 실행)

**역할(worktree role)이 허용하는 레이어만 직접 편집**한다. 역할 밖 수정은 handoff fix spec 으로 남긴다 (다른 워크트리가 소비).

실행 규칙:
- 계획에 명시된 변경만. drive-by refactor 금지.
- 기존 코드 패턴 준수. 신규 라이브러리 도입 금지.
- 회귀 방지 테스트를 Phase 4 계획대로 추가.
- **TDD 스킬 적용** — 수정은 RED (버그 재현 테스트) → GREEN (수정) → REFACTOR 순으로.
- Lint/analyzer 실행:
  - Python: `cd server && uv run ruff check <file>` 또는 `python -m py_compile <file>`
  - Dart: `cd app && dart analyze <file>`

DB 스키마 변경이 있으면 새 alembic migration 을 만들고 `upgrade head` 로 적용. 기존 migration 절대 수정 금지.

## Phase 6 — Verify (검증)

**Phase 1 재현 명령 그대로** 다시 실행해 PASS 확인. 같은 명령이어야 한다.

추가로:
- 영향 층 범위 테스트 (pytest/flutter test)
- Phase 5 에서 추가한 회귀 테스트 — 수정 전 코드에서는 실패하고 수정 후 통과하는지 확인
- Linter

재현이 여전히 실패하면 Phase 2 로 복귀. "고쳤다" 선언 금지.

이전에 통과하던 테스트가 새로 실패하면 회귀 도입. `git checkout -- <file>` 로 되돌리고 Phase 4 재설계.

## Anti-Patterns (하지 말아야 할 것)

| Anti-pattern | 왜 금지 | 대신 |
|-------------|--------|------|
| `try/except` 로 에러 덮기 | 원인이 남아있어 재발 | 에러가 왜 발생했는지 Phase 2 추적 |
| `if x is not None` 방어 조건 추가 | None 이 들어오는 경로를 모르는 채 봉합 | 누가 None 을 넘기는지 찾아 거기서 수정 |
| "이 테스트는 flaky 하니 skip" | flake 는 경쟁 조건의 증거 | Phase 3 로 race 조건 확정 |
| 여러 변경을 한 번에 commit | 어느 것이 원인 수정인지 불명 | 하나의 원인만 고치고 검증 |
| 재현 안 되는데 "아마 이 코드가 문제" 추측 수정 | 증거 부재 | Phase 1 로 복귀, 재현 시나리오 요청 |

## Handoff (다른 스킬/에이전트로 넘길 때)

- 수정 실행 본체는 `backend-builder` / `flutter-builder` — 본 스킬은 진단과 계획을 담당, 실행 시 builder 체인에 tdd 스킬 적용
- 수정 이후 회고는 `retrospective` 스킬의 "What could improve" / "Process signal" 에 기록 (같은 버그 class 재발 방지)
- 보고서 작성은 `debugger` 에이전트의 Phase 7 또는 `doc-writer` 가 담당

## 관련 규칙

- `.claude/agents/debugger.md` — 이 스킬의 에이전트 실행 껍데기
- `.claude/skills/tdd/SKILL.md` — Phase 5 에서 참조
- `.claude/skills/verification-before-completion/SKILL.md` — Phase 6 의 검증 형식
- `.claude/rules/verification.md` — 증거 기반 보고 형식
