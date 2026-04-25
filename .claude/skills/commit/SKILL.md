---
name: commit
description: Stage, commit, and push current changes with auto-generated message. Use after any work session to quickly save and deploy.
user_invocable: true
---

# Commit — Stage, Commit & PR Merge to Main

Lightweight skill to commit current work and merge to main via PR.

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

## Step 3: Commit & PR Merge to Main

### 3-1. Generate commit message

- If user provided a message argument, use it as-is
- If not, generate from the diff:
  - `feat:` for new functionality
  - `fix:` for bug fixes
  - `chore:` for config/tooling changes
  - `refactor:` for restructuring
  - Keep under 72 chars, Korean or English matching the diff context

### 3-2. Stage, commit, push via PR

```bash
git add <changed files>   # specific files, not -A
git commit -m "<message>

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

Then push via PR (see `.claude/rules/git-workflow.md` § PR-Based Merge to Main):

```bash
BRANCH=$(git branch --show-current)

# 1. Rebase on main
git fetch origin main
if ! git rebase origin/main; then
  # DO NOT auto-abort. Hand off to /resolve-conflict.
  echo "Rebase conflict — invoke /resolve-conflict"
  exit 1
fi

# 2. Push worktree branch
git push origin "$BRANCH" --force-with-lease

# 3. Create PR — 한글 제목+본문
gh pr create --base main --head "$BRANCH" \
  --title "<type>(<scope>): <한글 설명>" \
  --body "$(cat <<'PREOF'
## 요약
- <무엇을 왜 변경했는지 1-3줄>

## 변경 사항
- `path/file.ext` — 변경 내용

## 테스트
- [ ] <검증 항목>

🤖 Generated with [Claude Code](https://claude.ai/code)
PREOF
)" 2>/dev/null || true

# 4. Merge PR — STOP if fails
PR_NUM=$(gh pr view "$BRANCH" --json number -q .number)
if ! gh pr merge "$PR_NUM" --merge --delete-branch=false; then
  echo "Auto-merge failed — STOP. PR #$PR_NUM left open."
  exit 1
fi

# 5. Sync local
git fetch origin main
git rebase origin/main
```

**On rebase conflict**: do not abort. Invoke the `resolve-conflict` skill:

1. Read `.claude/skills/resolve-conflict/SKILL.md` and follow its 7 phases.
2. If the skill reports **success**, resume from step 2 (push branch + PR).
3. If the skill reports **STOP**, emit the STOP report to the user.

**On merge failure**: STOP. Do not force merge. PR is left open for manual review.

**IMPORTANT**: No `git push origin HEAD:main`. No `--force`. See `.claude/rules/git-workflow.md`.

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

impl-log 파일명은 `impl-log/{type}-{slug}.md` 형식 (예: `impl-log/feat-slice-07.md`).

Commit and push the impl-log using the same PR flow from Step 3-2:

```bash
git add impl-log/<name>.md
git commit -m "docs: add impl-log for <name>

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"

# PR merge — same as Step 3-2
BRANCH=$(git branch --show-current)
git fetch origin main && git rebase origin/main
git push origin "$BRANCH" --force-with-lease
gh pr create --base main --head "$BRANCH" --title "docs: add impl-log for <name>" --body "impl-log" 2>/dev/null || true
PR_NUM=$(gh pr view "$BRANCH" --json number -q .number)
gh pr merge "$PR_NUM" --merge --delete-branch=false || { echo "Merge failed — STOP"; exit 1; }
git fetch origin main && git rebase origin/main
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
