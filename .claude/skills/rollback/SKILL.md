---
name: rollback
description: Revert a feature implementation — delete PR, delete remote branch, reset code to pre-implementation state. Use when user says "롤백", "되돌려", "취소해", or asks to undo recent changes.
user_invocable: true
---

# Rollback — Revert Feature & Clean Up PR

Undo a feature implementation: revert code, delete PR, delete branch, update impl-log.

Argument: `<PR number or branch name>` — if omitted, auto-detect the most recent PR.

---

## Step 1: Identify Target

If argument provided, use it. Otherwise:

```bash
gh pr list --author @me --limit 5 --json number,title,headRefName,state
```

Print the list and pick the most recent open PR. If ambiguous, ask user.

Read the implementation log for context:

```bash
cat impl-log/<branch-name>.md 2>/dev/null
```

## Step 2: Confirm Scope

Print what will be rolled back:

```
## Rollback Target

| Item | Value |
|------|-------|
| PR | #{number} — {title} |
| Branch | {branch-name} |
| Files | {list from impl-log or git diff} |
```

## Step 3: Close PR & Delete Remote Branch

```bash
gh pr close {number} --delete-branch
```

This closes the PR and deletes the remote branch in one command.

## Step 4: Clean Up Local Branch

```bash
# Ensure we're on main
git checkout main

# Delete local branch if it exists
git branch -D {branch-name} 2>/dev/null || true

# Ensure local main is clean (no leftover changes)
git checkout -- .
```

## Step 5: Verify Clean State

```bash
git status
git branch --list
```

Confirm:
- On `main` branch
- No uncommitted changes
- Feature branch deleted locally

## Step 6: Update Implementation Log

Update `impl-log/<branch-name>.md` — add rollback record at the top:

```markdown
> **ROLLED BACK** on {YYYY-MM-DD}. PR #{number} closed and branch deleted.
```

Commit the updated log:

```bash
git add impl-log/<branch-name>.md
git commit -m "docs: mark {branch-name} as rolled back

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"

# rebase-retry push — on conflict, invoke /resolve-conflict
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

## Step 7: Summary

```
## Rollback Complete

| Item | Value |
|------|-------|
| PR | #{number} — closed |
| Branch | {branch-name} — deleted (local + remote) |
| Code | reverted to main |
| Impl Log | updated with rollback marker |
```
