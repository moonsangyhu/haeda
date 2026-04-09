---
name: commit
description: Stage, commit, and push current changes with auto-generated message. Use after any work session to quickly save and deploy.
user_invocable: true
---

# Commit — Stage, Commit & Push to Main

Lightweight skill to commit current work and push directly to main. No branches, no PRs.

Argument: `<optional commit message>` — if omitted, auto-generate from diff.

---

## Step 1: Analyze Changes

```bash
git status
git diff --stat
```

If no changes exist, print "변경 사항이 없습니다." and stop.

## Step 2: Run Tests & Build

Run tests ONLY for the affected area (skip if no source files changed):

- **app/ changed**: `cd app && flutter analyze && flutter test && flutter build web`
- **server/ changed**: `cd server && uv run pytest -v --tb=short`
- **Both changed**: run both
- **Only config/.claude files changed**: skip tests

If tests or build fail, print failures and STOP. Do not commit broken code.

## Step 3: Commit & Push to Main

### 3-1. Generate commit message

- If user provided a message argument, use it as-is
- If not, generate from the diff:
  - `feat:` for new functionality
  - `fix:` for bug fixes
  - `chore:` for config/tooling changes
  - `refactor:` for restructuring
  - Keep under 72 chars, Korean or English matching the diff context

### 3-2. Stage, commit, push directly to main

```bash
git add <changed files>   # specific files, not -A
git commit -m "<message>

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
git push origin main
```

**IMPORTANT**: No branches. No PRs. Always commit and push directly to main.

## Step 4: Write Implementation Log

Create `impl-log/<commit-type>-<short-desc>.md` with implementation record.

```bash
mkdir -p impl-log
```

**Template** (`impl-log/<commit-type>-<short-desc>.md`):

```markdown
# {commit message}

- **Date**: {YYYY-MM-DD}
- **Commit**: {hash}
- **Area**: {frontend / backend / both / config}

## What Changed

{1-3 sentence summary of the feature/fix and why it was needed}

## Changed Files

| File | Change |
|------|--------|
| {path} | {brief description} |

## Implementation Details

{Key decisions, patterns used, dependencies added/removed.
Enough detail that another agent can understand what was done and undo it if needed.}

## Tests & Build

- Analyze: {pass / N issues}
- Tests: {N passed, M failed}
- Build: {pass / skip}
```

Commit and push the impl-log:

```bash
git add impl-log/<name>.md
git commit -m "docs: add impl-log for <name>

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
git push origin main
```

## Step 5: Rebuild (if source changed)

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

## Step 6: Summary

```
## Commit Complete

| Item | Value |
|------|-------|
| Commit | {hash} |
| Message | {message} |
| Files | {N} changed |
| Tests | {passed/skipped} |
| Build | {passed/skipped} |
| Impl Log | impl-log/{name}.md |
| Rebuild | {done/skipped} |
```
