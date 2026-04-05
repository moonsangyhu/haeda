---
name: commit
description: Stage, commit, and push current changes with auto-generated message. Use after any work session to quickly save and deploy.
user_invocable: true
disable_model_invocation: true
---

# Commit — Quick Stage, Commit, Push & Rebuild

Lightweight skill to commit current work without full feature-flow ceremony.

Argument: `<optional commit message>` — if omitted, auto-generate from diff.

---

## Step 1: Analyze Changes

```bash
git status
git diff --stat
```

If no changes exist, print "변경 사항이 없습니다." and stop.

## Step 2: Run Tests

Run tests ONLY for the affected area (skip if no source files changed):

- **app/ changed**: `cd app && flutter analyze && flutter test`
- **server/ changed**: `cd server && uv run pytest -v --tb=short`
- **Both changed**: run both
- **Only config/.claude files changed**: skip tests

If tests fail, print failures and STOP. Do not commit broken code.

## Step 3: Commit & Push

### 3-1. Generate commit message

- If user provided a message argument, use it as-is
- If not, generate from the diff:
  - `feat:` for new functionality
  - `fix:` for bug fixes
  - `chore:` for config/tooling changes
  - `refactor:` for restructuring
  - Keep under 72 chars, Korean or English matching the diff context

### 3-2. Stage, commit, push

```bash
git add <changed files>   # specific files, not -A
git commit -m "<message>

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
git push origin main
```

## Step 4: Rebuild (if source changed)

Skip if only config/.claude files changed.

- **app/ changed**: `docker compose up --build -d frontend`
- **server/ changed**: `docker compose up --build -d backend`
- **Both**: `docker compose up --build -d backend frontend`

Set Bash timeout to 600000.

### Health Check

```bash
curl -s --max-time 10 http://localhost:8000/health
curl -s --max-time 5 -o /dev/null -w "%{http_code}" http://localhost:3000
```

## Step 5: Summary

```
## Commit Complete

| Item | Value |
|------|-------|
| Commit | {hash} |
| Message | {message} |
| Files | {N} changed |
| Tests | {passed/skipped} |
| Push | done |
| Rebuild | {done/skipped} |
```
