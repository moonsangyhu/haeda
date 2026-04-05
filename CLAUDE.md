# Haeda

Collaborative challenge app — a calendar-based motivation service where seasonal icons are completed only when all participants verify.
Currently building MVP for a hospital pilot (4 weeks). Flutter + FastAPI + PostgreSQL + Kakao OAuth.

## Source of Truth

All implementation decisions are based on these 4 documents. When code and docs conflict, docs are correct.

- `docs/prd.md` — feature list, P0/P1 scope, non-functional requirements, success metrics
- `docs/user-flows.md` — screen flows, screen structure
- `docs/domain-model.md` — entities, fields, constraints, business rules
- `docs/api-contract.md` — REST endpoints, request/response schemas, error codes

docs/ files must not be modified in principle. User approval required if modification is needed.

## MVP Guardrails

- Implement P0 scope only. Do not build P1 (public discovery, push notifications, Apple login) or features excluded from MVP.
- Do not add entities, endpoints, or screens not defined in the PRD.
- If a decision corresponding to `docs/prd.md` §9 Open Questions is needed, confirm with user before implementing.

## Implementation Rules

- **Terminology**: Class names, variable names, and API paths in code follow the English terms from docs (Challenge, Verification, DayCompletion, ChallengeMember, Comment).
- **API contract**: Paths, field names, types, and error codes must match `api-contract.md` exactly. Responses use `{"data": ...}` / `{"error": {"code": "...", "message": "..."}}` envelope.
- **Flutter**: Feature-first structure, Riverpod, GoRouter, dio. Detailed rules in `.claude/skills/flutter-mvp/`.
- **FastAPI**: SQLAlchemy 2.0 async, Pydantic v2, Alembic. Detailed rules in `.claude/skills/fastapi-mvp/`.
- **Season icons**: Mar-May spring, Jun-Aug summer, Sep-Nov fall, Dec-Feb winter.
- **Path-specific rules**: `.claude/rules/server-guard.md` auto-loads for server/ work, `.claude/rules/app-guard.md` auto-loads for app/ work.

## Workflow Rules

Vertical slice development flow:

1. **Plan (Plan-first)**: Enter Plan Mode with Shift+Tab, then run `/slice-planning {slice-name}`. Do not implement until the plan is approved.
2. **Spec verification**: Use `spec-keeper` agent to verify spec consistency of the plan. Block implementation if P0 scope, entities, or error codes don't match.
3. **Implementation**: Implement API with `backend-builder` -> implement UI with `flutter-builder`. Or implement directly as needed.
4. **Check**: Run `/mvp-slice-check {slice-name}` for completeness check. Run `/docs-drift-check` for code-docs consistency.
5. **Review**: Quality review with `qa-reviewer` agent.
6. **Remediation loop**: If QA verdict is "partial" or "incomplete", paste the remediation prompt into the relevant tab (backend/frontend) to fix -> QA re-review. Repeat until "complete". Use `/qa-remediation {slice-name}` if prompt regeneration is needed.
7. **Integration check**: Run `/smoke-test` to verify full stack operation in local environment.
8. **Record results**: Run `/slice-test-report {slice-name}` to save test report to `test-reports/`. Git commit target.
9. **Next slice transition**: On "complete" verdict, paste the next-slice prompts output by QA into each tab to start next cycle. Or manually generate with `/next-slice-planning`.

### Verification Principles

- **"Prove it works."** Every slice is judged complete by actual test execution results.
- Mock success, fallback path success, or build-only pass is NOT "proof of working".
- Must cite passed/failed counts from pytest/flutter test output.
- Distinguish between actually verified items and unverified items. Do not declare "complete" by estimation.
- Do not declare slice complete without smoke test.

### Session Naming

- Start sessions in `claude -n slice-{NN}-{layer}` format for slice work (e.g., `claude -n slice-04-backend`).
- Use `claude --worktree slice-{NN} -n slice-{NN}` format for parallel worktree work.
- See `docs/worktree-runbook.md` for detailed rules.

### Slice Automation (MVP)

Orchestrator that automatically implements and verifies a single slice:
- `make slice-auto` — auto-detect next slice + plan -> build -> qa -> complete
- `make slice-auto SLICE=slice-07` — run specific slice
- `make slice-status SLICE=slice-07` — check status
- `make slice-resume SLICE=slice-07` — resume after interruption
- `make slice-clean SLICE=slice-07` — clean artifacts

Rules:
- Max 1 auto-retry for remediation. Manual intervention after failure.
- State files (`automation/runs/<slice>/run.json`) are compact pointer-based. Logs in separate files.
- backend/frontend run in parallel via git worktrees. No cross-modification between app/ and server/.
- Agent SDK preferred, CLI fallback. Details: `scripts/automation/`.

Misc:
- Do not hardcode `.env`, secrets, or credentials in code.
- Do not touch app/ code when working on server/. Vice versa.
- **Local environment (Container-First)**: Start full stack with `docker compose up --build -d`. Same as `/local`. Stop with `/local stop`, check status with `/local status`, reset with `/local reset`.

## CLAUDE.md Update Rules

This file is the project's working rulebook. Update in these cases:

- **Repeated mistakes**: If Claude makes the same mistake 2+ times, add a prevention rule.
- **New pattern established**: When the team adopts a new coding pattern or workflow, reflect it.
- **Rule deprecated**: Delete rules that are no longer valid. Do not comment them out.

Do NOT update with:
- Implementation details (verifiable from code)
- One-off debugging records (keep in test-reports/)
- Detailed procedures (separate into skills/ or docs/)

Keep CLAUDE.md short and strong. Target under 200 lines.

## Out of Scope

CI/CD pipelines, deployment configuration, production infrastructure (K8s), monitoring setup.

> **Exception**: Local development `docker compose` is allowed. Start full stack with `docker compose up --build`. Production optimization and CI/CD integration are out of scope.
