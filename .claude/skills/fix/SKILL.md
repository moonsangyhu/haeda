---
name: fix
description: Lightweight bug fix flow. Analyze → fix → QA → report → commit → push → rebuild. No approval gates.
user_invocable: true
disable_model_invocation: true
---

# Fix — Lightweight Bug Fix Flow

Fast-track workflow for bug fixes. Runs end-to-end without approval gates.

### Model Strategy (Token Optimization)

| Phase | Executor | Model | Reason |
|-------|----------|-------|--------|
| Step 1 (Analyze) | Main | Opus | Root cause diagnosis |
| Step 2 (Fix) | `flutter-builder` / `backend-builder` agent | Sonnet | Mechanical fix |
| Step 3 (QA) | `qa-reviewer` agent | Sonnet | Checklist verification |
| Step 4-7 (Report, Push, Rebuild) | Main | Opus | Coordination |

**Rule**: Steps 2-3 MUST be delegated to agents (Sonnet). Do NOT fix or test directly in the main conversation.

Argument: `<bug description>`

---

## Step 1: Analyze

### 1-1. Search Codebase

Use Grep and Glob to find files related to the bug. Read the relevant code to understand the root cause.

### 1-2. Print Diagnosis

```
## Bug Fix — Diagnosis

- **Bug**: {user's description}
- **Root cause**: {one-line explanation}
- **Affected files**: {file paths}
- **Fix approach**: {one-line plan}
```

Auto-proceed to Step 2. Do not wait for approval.

## Step 2: Fix

Delegate the fix to the appropriate specialized agent based on the affected area.

### Frontend only (app/)

Spawn `flutter-builder` agent with:
- Bug description and root cause from Step 1
- Affected files list
- Instruction: "fix only, no refactor, no feature additions"
- Scope: `app/` only. NEVER touch `server/`.

### Backend only (server/)

Spawn `backend-builder` agent with:
- Bug description and root cause from Step 1
- Affected files list
- Instruction: "fix only, no refactor, no feature additions"
- Scope: `server/` only. NEVER touch `app/`.

### Cross-Layer (both)

Spawn both agents in parallel:
1. `backend-builder` agent — fixes server/ changes
2. `flutter-builder` agent — fixes app/ changes
Wait for both to complete.

### Agent Rules
- Each agent works ONLY in its designated directory
- No agent may modify `docs/`
- No agent may run `git commit`, `git add`, or `git push`
- Do NOT refactor surrounding code
- Do NOT add features beyond the fix
- Follow existing code patterns

## Step 3: QA

### 3-1. Run Tests

Run tests for the affected area:

- **app/ changed**: `cd app && flutter analyze && flutter test`
- **server/ changed**: `cd server && uv run pytest -v --tb=short`
- **Both**: run both

### 3-2. Spawn QA Agent

Spawn `qa-reviewer` agent with:
- Bug description and root cause from Step 1
- Changed files from Step 2
- Test results from 3-1

### 3-3. Handle QA Verdict

| Verdict | Action |
|---------|--------|
| **Complete** | Proceed to Step 4 |
| **Partial / Incomplete** | Fix issues, re-run QA (max 2 retries) |

After 2 failed retries, STOP and ask user.

## Step 4: Report

Generate a fix report at `docs/reports/YYYY-MM-DD-fix-<slug>.md`.

The `<slug>` is derived from the bug description (lowercase, hyphens, max 50 chars).

### Report Template

```markdown
# Fix Report: {summary}

- Date: {YYYY-MM-DD}
- Area: {frontend / backend / both}
- Status: {complete / partial}

## Bug
{user's original description}

## Root Cause
{diagnosis from Step 1}

## Changed Files
- {file path} — {brief description of change}

## Fix Details
{what was changed and why}

## QA Results
- Backend tests: {N passed, M failed / N/A}
- Frontend tests: {N passed, M failed / N/A}
- Lint: {pass / N issues}
- QA verdict: {complete / partial / incomplete}

## Remaining Risks
- {risk description, or "None identified"}
```

## Step 5: Commit & Push

```bash
git add <changed files> docs/reports/{report-file}
git commit -m "fix: <concise description>

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
git push origin main
```

## Step 6: Rebuild & Verify

- **app/ changed**: `docker compose up --build -d frontend`
- **server/ changed**: `docker compose up --build -d backend`
- **Both**: `docker compose up --build -d backend frontend`

Set Bash timeout to 600000.

### Health Check

```bash
curl -s --max-time 10 http://localhost:8000/health
curl -s --max-time 5 -o /dev/null -w "%{http_code}" http://localhost:3000
```

If health check fails, print logs and STOP.

## Step 7: Summary

```
## Bug Fix Complete

| Item | Value |
|------|-------|
| Bug | {description} |
| Root cause | {cause} |
| Fix | {what changed} |
| QA | complete |
| Report | docs/reports/{filename} |
| Commit | {hash} |
| Tests | {N passed, M failed} |
| Push | done |
| Rebuild | done |
| Health | OK |
```

---

## Guardrails

- No approval gates — runs fully automatic
- Only STOP on: QA failure (after 2 retries), health check failure
- Do not modify `docs/` files (except `docs/reports/`)
- Do not add features — fix only
- Do not touch unrelated files
