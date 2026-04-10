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
