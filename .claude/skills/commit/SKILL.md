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

### 3-2. Stage, commit, push via rebase-retry

```bash
git add <changed files>   # specific files, not -A
git commit -m "<message>

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

Then push via the rebase-retry loop (NEVER bare `git push`):

```bash
for attempt in 1 2 3; do
  git fetch origin main
  if ! git rebase origin/main; then
    # DO NOT auto-abort. Hand off to /resolve-conflict.
    break
  fi
  if git push origin HEAD:main; then
    exit 0
  fi
  echo "Push rejected (non-fast-forward), retry $attempt/3"
  sleep 1
done
```

**On rebase conflict**: the loop breaks without aborting so the repo stays in rebase-in-progress state. Next, invoke the `resolve-conflict` skill:

1. Read `.claude/skills/resolve-conflict/SKILL.md` and follow its 7 phases.
2. If the skill reports **success**, re-run the push step: `git fetch origin main && git push origin HEAD:main`. Retry the push up to 3 times with rebase if needed.
3. If the skill reports **STOP**, do NOT continue. Emit the skill's STOP report to the user. The repo is left in rebase-in-progress state per the skill's contract.

**IMPORTANT**: No branches. No PRs. No bare `git push`. No `--force`. See `.claude/rules/worktree-parallel.md`.

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

The impl-log filename MUST embed the worktree role (`backend` / `front` / `qa` / `claude`) to prevent parallel-worktree collisions — e.g. `impl-log/feat-slice-07-backend.md`. See `.claude/rules/worktree-parallel.md` §Shared Directories.

Commit and push the impl-log using the same rebase-retry loop from Step 3-2:

```bash
git add impl-log/<name>-<role>.md
git commit -m "docs: add impl-log for <name>

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"

# rebase-retry push — on conflict, invoke /resolve-conflict instead of aborting
for attempt in 1 2 3; do
  git fetch origin main
  if ! git rebase origin/main; then
    echo "Rebase conflict — invoke .claude/skills/resolve-conflict/SKILL.md, then retry push"
    break
  fi
  git push origin HEAD:main && break
  sleep 1
done
```

## Step 5: Rebuild & Verify (if source changed)

Skip if only config/.claude files changed. Set Bash timeout to 600000.

### 5-1. Backend (server/ changed)

```bash
docker compose up --build -d backend
curl -s --max-time 10 http://localhost:8000/health
```

### 5-2. iOS Simulator 실행 (app/ changed) — MANDATORY

**app/ 파일이 하나라도 변경되었으면 반드시 실행. 예외 없음.**

```bash
cd app && flutter run -d <simulator-device-id>
```

- `flutter run`은 빌드를 포함하므로 별도 `flutter build` 불필요.
- **`flutter build ios --simulator`(빌드만)는 검증으로 인정하지 않는다.** 시뮬레이터에서 앱이 실행되어 화면을 확인할 수 있어야 검증 완료.
- `flutter build web`은 검증으로 인정하지 않는다.
- `docker compose up --build -d frontend`는 iOS 빌드를 대체할 수 없다.
- 이 단계를 건너뛰면 작업 완료로 선언할 수 없다.
- 실행 실패 시 수정 후 재실행. 절대 skip 금지.

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
| iOS Build | {pass/skipped} |
```
