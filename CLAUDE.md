# Haeda

Collaborative challenge app — calendar-based motivation service. Flutter + FastAPI + PostgreSQL + Kakao OAuth. Hospital pilot MVP (4 weeks).

## Source of Truth

- `docs/prd.md` — features, P0/P1 scope, NFRs, success metrics
- `docs/user-flows.md` — screen flows, screen structure
- `docs/domain-model.md` — entities, fields, business rules
- `docs/api-contract.md` — REST endpoints, schemas, error codes

When code and docs conflict, docs win. Do not modify docs/ without user approval.

## MVP Guardrails

- P0 features only. P1+ implemented on user request.
- Open Questions (`docs/prd.md` section 9): confirm with user before deciding.

## Rules

Detailed rules in `.claude/rules/`:

- **coding-style.md** — terminology, API format, season icons, file size limits
- **git-workflow.md** — conventional commits, session naming, branch naming
- **agents.md** — 10-agent team, dispatch rules, gate rules
- **workflow.md** — 9-step slice flow, verification principles
- **worktree-parallel.md** — role contract, rebase-retry push, deployer lockfile (MANDATORY for all worktree work)
- **worktree-task-report.md** — 작업 단위마다 `docs/reports/YYYY-MM-DD-{role}-{slug}.md` 보고서 생성 의무 (MANDATORY)
- **claude-config-sync.md** — claude role의 `.claude/**` 변경은 즉시 push, 다른 role은 작업 시작 전 반드시 rebase (MANDATORY)
- **autonomous-execution.md** — 파일 수정·명령·커밋·푸시는 허락 없이 즉시 수행. 사용자 결정이 필요한 경우만 질문 (MANDATORY)
- **automation.md** — slice-auto, refinement pipeline
- **security.md** — secrets, validation, encoding
- **app-guard.md** — Flutter rules (app/** auto-load)
- **server-guard.md** — FastAPI rules (server/** auto-load)
- **docs-protection.md** — docs immutability (docs/** auto-load)

## Out of Scope

CI/CD, deployment, production infra (K8s), monitoring. Local `docker compose` allowed.
