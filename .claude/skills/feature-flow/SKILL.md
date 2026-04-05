---
name: feature-flow
description: Enforced workflow for all feature work. Covers requirements analysis, planning, implementation (single or cross-layer), QA, reporting, and conditional push.
user_invocable: true
disable_model_invocation: true
---

# Feature Flow — Enforced Feature Workflow

All feature work MUST follow this 8-step workflow. No step may be skipped.
**Auto-proceed mode**: All steps run end-to-end without user approval gates. Only STOP for user input when: QA fails 2 times, push conditions are not met, or a health check fails.

### Model Strategy (Token Optimization)

| Phase | Executor | Model | Reason |
|-------|----------|-------|--------|
| Step 1 (Analysis) | Main | Opus | Requires judgment, codebase understanding |
| Step 2 (Plan) | Main | Opus | Architecture decisions |
| Step 3 (Implementation) | `flutter-builder` / `backend-builder` agent | Sonnet | Mechanical coding, pattern-following |
| Step 4 (QA) | `qa-reviewer` agent | Sonnet | Checklist-based verification |
| Step 5-8 (Report, Push, Rebuild) | Main | Opus | Coordination, minimal tokens |

**Rule**: Steps 3-4 MUST be delegated to agents (Sonnet). Do NOT implement or test directly in the main conversation — always spawn the appropriate agent.

Argument: `<requirement description>`

---

## Step 1: Requirements Analysis

Parse the user's requirement and produce a structured scope document.

### 1-1. Read Source of Truth (skim relevant sections only)

- `docs/prd.md` — verify P0/P1 scope
- `docs/user-flows.md` — find affected screens
- `docs/api-contract.md` — find affected endpoints
- `docs/domain-model.md` — find affected entities (only if domain logic is involved)

### 1-2. Search Codebase

Use Glob and Grep to find files related to the requirement.

### 1-3. Output Scope Document

Print the following to the user:

```
## Feature Flow — Requirements

### Requirement
{user's original request}

### Summary
{one-line summary}

### Affected Area
{frontend / backend / both}

### Acceptance Criteria
1. {criterion}
2. {criterion}
...

### Out of Scope
- {exclusion}
...

### Affected Files (estimated)
- {file paths found in codebase search}

### Spec References
- prd.md: {section}
- user-flows.md: {flow}
- api-contract.md: {endpoints}
```

### 1-4. Print & Proceed

Print the scope document for visibility, then **auto-proceed to Step 2**. Do not wait for approval.

---

## Step 2: Plan

### 2-1. Create Implementation Plan

Based on the requirements, create a plan internally (do NOT enter Plan Mode):

- **If single area (frontend only or backend only)**:
  - List files to create/modify
  - List the subagent to use (`flutter-builder` for frontend, `backend-builder` for backend)
  - Define test strategy

- **If cross-layer (both app/ and server/)**:
  - Split into backend plan and frontend plan
  - Define execution order (typically backend first, then frontend)
  - List subagents: `backend-builder` + `flutter-builder` (parallel via Agent teams)
  - Define integration test strategy

### 2-2. Print & Proceed

Print the plan summary for visibility, then **auto-proceed to Step 3**. Do not wait for approval.

---

## Step 3: Implementation

### Single Area (frontend OR backend)

Use the appropriate subagent:

- **Frontend only**: Spawn `flutter-builder` agent
  - Scope: `app/` only. NEVER touch `server/`.
  - After completion: run `cd app && flutter test`

- **Backend only**: Spawn `backend-builder` agent
  - Scope: `server/` only. NEVER touch `app/`.
  - After completion: run `cd server && uv run pytest -v --tb=short`

### Cross-Layer (both)

Use Agent teams for parallel execution:

1. Spawn `backend-builder` agent — implements server/ changes
2. Spawn `flutter-builder` agent — implements app/ changes
3. Wait for both to complete
4. Run integration check:
   ```bash
   cd server && uv run pytest -v --tb=short
   cd app && flutter test
   ```

### Implementation Rules

- Each subagent works ONLY in its designated directory
- No subagent may modify `docs/`
- No subagent may run `git commit`, `git add`, or `git push`
- Follow existing code patterns (Riverpod, GoRouter, SQLAlchemy async, Pydantic v2)

---

## Step 4: QA

Use the `qa-reviewer` agent to verify the implementation.

### 4-1. Run Tests

```bash
# Backend (if changed)
cd server && uv run pytest -v --tb=short

# Frontend (if changed)
cd app && flutter test

# Lint (frontend)
cd app && flutter analyze
```

### 4-2. Spawn QA Agent

Spawn `qa-reviewer` with the feature context:
- Acceptance criteria from Step 1
- Changed files from Step 3
- Test results from 4-1

### 4-3. Handle QA Verdict

| Verdict | Action |
|---------|--------|
| **Complete** | Proceed to Step 5 |
| **Partial** | Fix issues using the appropriate subagent, then re-run QA (max 2 retries) |
| **Incomplete** | Fix critical issues, then re-run QA (max 2 retries) |

After 2 failed retries, STOP and ask the user for guidance.

---

## Step 5: Report

Generate a feature report at `docs/reports/YYYY-MM-DD-<slug>.md`.

The `<slug>` is derived from the summary (lowercase, hyphens, max 50 chars).

### Report Template

```markdown
# Feature Report: {summary}

- Date: {YYYY-MM-DD}
- Area: {frontend / backend / both}
- Status: {complete / partial}

## Requirement
{original requirement text}

## Changed Files
- {file path} — {brief description of change}
...

## Frontend Changes
{summary of UI/widget changes, or "N/A"}

## Backend Changes
{summary of API/model changes, or "N/A"}

## QA Results
- Backend tests: {N passed, M failed / skipped}
- Frontend tests: {N passed, M failed / skipped}
- Lint: {pass / N issues}
- QA verdict: {complete / partial / incomplete}

### Acceptance Criteria
| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | {criterion} | PASS/FAIL | {brief} |
...

## Remaining Risks
- {risk description, or "None identified"}

## Push
- Eligible: {yes / no}
- Reason: {why eligible or not}
```

---

## Step 6: Push Eligibility Check

Evaluate whether the work is ready to push:

### Push Conditions (ALL must be true)

1. QA verdict is "complete"
2. All tests pass (0 failures)
3. Report file exists in `docs/reports/`
4. No files outside the affected area were modified

### If Eligible

**Auto-proceed to Step 7.** Print a one-line summary for visibility:
```
Push 조건 충족 — 자동 진행 (변경 {N}개, QA complete, tests passed)
```

### If Not Eligible

Print:
```
Push 조건 미충족:
- {reason 1}
- {reason 2}

수동으로 수정 후 다시 시도하거나, 강제 진행하려면 말씀해주세요.
```

---

## Step 7: Commit & Push

Auto-execute when push conditions are met.

### 7-1. Stage and Commit

Use `/role-scoped-commit-push` with the appropriate role:

- Frontend only: `/role-scoped-commit-push front feat: {summary}`
- Backend only: `/role-scoped-commit-push backend feat: {summary}`
- Cross-layer: Commit each area separately:
  1. `/role-scoped-commit-push backend feat: {summary}`
  2. `/role-scoped-commit-push front feat: {summary}`

### 7-2. Also Commit Report

```bash
git add docs/reports/{report-file}
git commit -m "docs: add feature report for {summary}

Co-Authored-By: Claude <noreply@anthropic.com>"
git push
```

### 7-3. Proceed to Step 8 (Local Rebuild)

---

## Step 8: Local Rebuild & Verify

After push, rebuild the local Docker environment so the running app reflects the latest changes.

### 8-1. Rebuild Affected Services

Determine which services to rebuild based on the affected area:

- **Frontend only**: `docker compose up --build -d frontend`
- **Backend only**: `docker compose up --build -d backend`
- **Both**: `docker compose up --build -d backend frontend`

Set Bash tool timeout to 600000 (10 minutes) — Flutter web build may be slow.

### 8-2. Health Check

```bash
# Backend
curl -s --max-time 10 http://localhost:8000/health

# Frontend
curl -s --max-time 5 -o /dev/null -w "%{http_code}" http://localhost:3000
```

### 8-3. Final Output

```
## Feature Flow Complete

| Item | Value |
|------|-------|
| Feature | {summary} |
| Area | {frontend / backend / both} |
| QA | complete |
| Report | docs/reports/{filename} |
| Commits | {hash1}, {hash2} |
| Push | done |
| Local rebuild | done |
| Health check | Backend OK, Frontend 200 |
```

If a service fails health check, print `docker compose logs {service}` output and ask the user for guidance.

---

## Guardrails

These rules apply at ALL steps:

- **P0/P1 scope**: Do not implement features beyond P1. Block if user requests out-of-scope features.
- **Spec match**: Code must match docs/api-contract.md paths, field names, error codes exactly.
- **No doc edits**: Never modify docs/ files (except docs/reports/).
- **Cross-boundary prohibition**: Frontend agents never touch server/. Backend agents never touch app/.
- **Plan first**: Never start implementation without an approved plan.
- **QA before push**: Never push without QA verdict "complete".
- **Report before push**: Never push without a report in docs/reports/.
- **Auto-proceed**: All steps run without user approval. Only STOP when: QA fails 2 times, push conditions are not met, or health check fails.
