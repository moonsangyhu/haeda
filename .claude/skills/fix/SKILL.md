---
name: fix
description: Lightweight bug fix flow. Analyze → fix → test → commit → push → rebuild. No approval gates.
user_invocable: true
disable_model_invocation: true
---

# Fix — Lightweight Bug Fix Flow

Fast-track workflow for bug fixes. Runs end-to-end without approval gates.

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

Apply the minimal change to fix the bug. Rules:
- Do NOT refactor surrounding code
- Do NOT add features beyond the fix
- Do NOT touch files unrelated to the bug
- Follow existing code patterns

## Step 3: Test

Run tests for the affected area:

- **app/ changed**: `cd app && flutter analyze && flutter test`
- **server/ changed**: `cd server && uv run pytest -v --tb=short`
- **Both**: run both

If tests fail:
- Attempt to fix (max 2 retries)
- If still failing after 2 retries, STOP and ask user

## Step 4: Commit & Push

```bash
git add <changed files>
git commit -m "fix: <concise description>

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
git push origin main
```

## Step 5: Rebuild & Verify

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

## Step 6: Summary

```
## Bug Fix Complete

| Item | Value |
|------|-------|
| Bug | {description} |
| Root cause | {cause} |
| Fix | {what changed} |
| Commit | {hash} |
| Tests | {N passed, M failed} |
| Push | done |
| Rebuild | done |
| Health | OK |
```

---

## Guardrails

- No approval gates — runs fully automatic
- Only STOP on: test failure (after 2 retries), health check failure
- Do not modify `docs/` files
- Do not add features — fix only
- Do not touch unrelated files
