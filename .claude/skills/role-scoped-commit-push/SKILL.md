---
name: role-scoped-commit-push
description: Stage, commit, and push only files within the allowed paths for each role (front/backend/qa/claude). Prevents accidental cross-role file commits in parallel sessions.
allowed-tools: "Bash Read Glob Grep"
argument-hint: "<front|backend|qa|claude> [commit message]"
---

# Role-Scoped Commit & Push

In parallel Claude sessions (front / backend / qa / claude), enforce that each role only stages, commits, and pushes changes within its own scope.

## Usage

```
/role-scoped-commit-push front feat: implement challenge detail screen
/role-scoped-commit-push backend fix: auth token verification logic
/role-scoped-commit-push qa add challenge creation tests
/role-scoped-commit-push claude add skill
```

If commit message is omitted, auto-generate from staged diff.

Argument: `$ARGUMENTS`

---

## Allowed Paths by Role

Two categories: **hard path boundary** (role-exclusive directories) and **shared directories** (any role may write, collision prevented by filename convention).

### Hard Path Boundary

| Role | Allowed Path Patterns |
|------|----------------------|
| `front` | `app/lib/**`, `app/pubspec.yaml`, `app/pubspec.lock` |
| `backend` | `server/app/**`, `server/alembic/**`, `server/alembic.ini`, `server/pyproject.toml`, `server/seed.py` |
| `qa` | `app/test/**`, `server/tests/**` |
| `claude` | `.claude/**`, `CLAUDE.md` |

The 4 roles' hard boundaries do not overlap. Any file under these paths belongs to at most one role.

### Shared Directories (filename MUST embed role)

| Directory | Required filename pattern | Rationale |
|-----------|--------------------------|-----------|
| `impl-log/` | contains `-{role}` or `-{role}.md` | doc-writer records per-worktree |
| `test-reports/` | contains `-{role}` or `{role}-` | QA evidence per-worktree |
| `docs/reports/` | `YYYY-MM-DD-{role}-*.md` | feature reports per-worktree |

`{role}` must be exactly one of `backend`, `front`, `qa`, `claude`.

Files in shared directories whose names do NOT embed the current role are OUT OF SCOPE (they belong to another worktree or are grandfathered legacy). Do not stage them.

### Source-of-Truth Docs (never writable)

- `docs/prd.md`, `docs/user-flows.md`, `docs/domain-model.md`, `docs/api-contract.md` — excluded for all roles, always.
- Other top-level `docs/**` files — excluded by default. Commit manually only.

---

## Strictly Forbidden

These commands must **never be executed under any circumstances**:

- `git add .`
- `git add -A`
- `git add --all`
- `git commit -a`
- `git commit --all`

Always explicitly `git add <file>` individual files.

---

## Execution Steps

### Step 0: Parse Arguments

Extract the first token from `$ARGUMENTS` as role, rest as commit message.

- If role is not one of `front`, `backend`, `qa`, `claude` -> error and abort:
  ```
  Error: Unknown role: {role}
  Allowed roles: front | backend | qa | claude
  ```
- If no role given -> error and abort:
  ```
  Error: Please specify a role.
  Usage: /role-scoped-commit-push <front|backend|qa|claude> [commit message]
  ```

### Step 1: Git Status Pre-check

```bash
git status --porcelain
git diff --cached --name-only
```

#### 1-1. Check for ongoing merge/rebase

```bash
git status
```

If output contains `You have unmerged paths`, `rebase in progress`, `merge in progress` -> abort immediately:
```
Error: merge/rebase in progress. Resolve it first then try again.
```

#### 1-2. Check staged files for out-of-scope files

```bash
git diff --cached --name-only
```

If staged files exist, check each file belongs to current role's allowed scope.
If any out-of-scope file found -> **do NOT unstage**, abort immediately:

```
Error: Staged files contain out-of-scope files for [{role}]:
  - server/app/main.py  (not allowed for front role)
  - docs/prd.md  (excluded for all roles)

Manually unstage first:
  git reset HEAD <file>
```

### Step 2: Collect Changed Files in Role Scope

```bash
git status --porcelain
```

Filter changed files (modified, added, deleted, untracked) to only those matching current role's allowed scope.

**Path Matching Rules:**

A file is in scope for a role if it matches EITHER (a) the hard path boundary OR (b) a shared directory with a role-embedded filename.

| Role | Hard Boundary | Shared-Dir Filename Pattern |
|------|---------------|----------------------------|
| `front` | Starts with `app/lib/` OR matches `app/pubspec.yaml` or `app/pubspec.lock` | `impl-log/*-front*.md`, `test-reports/*front*`, `docs/reports/*-front-*.md` |
| `backend` | Starts with `server/app/` OR `server/alembic/` OR matches `server/alembic.ini`, `server/pyproject.toml`, `server/seed.py` | `impl-log/*-backend*.md`, `test-reports/*backend*`, `docs/reports/*-backend-*.md` |
| `qa` | Starts with `app/test/` OR `server/tests/` | `impl-log/*-qa*.md`, `test-reports/*qa*`, `docs/reports/*-qa-*.md` |
| `claude` | Starts with `.claude/` OR matches `CLAUDE.md` | `impl-log/*-claude*.md`, `docs/reports/*-claude-*.md` |

Protected files (never in scope for any role):
- `docs/prd.md`, `docs/user-flows.md`, `docs/domain-model.md`, `docs/api-contract.md`
- Any `docs/**` file outside `docs/reports/`

Shared-directory files whose names do NOT embed the current role are out of scope — they belong to another worktree.

If no matching changed files -> exit:
```
Info: No changed files in [{role}] scope. Nothing to commit.
```

### Step 3: Stage

Stage only filtered files individually:

```bash
git add app/lib/features/challenge/screens/challenge_screen.dart
git add app/lib/features/challenge/providers/challenge_provider.dart
# ... one file at a time
```

### Step 4: Final Staged File Verification

```bash
git diff --cached --name-only
```

Verify **again** that all staged files are within current role's allowed scope.
If out-of-scope file found -> abort without committing:

```
Error: Verification failed: out-of-scope files found in staged files.
  - {file path}
Aborting commit. Clean up with `git reset HEAD` then try again.
```

### Step 5: Commit

#### 5-1. Determine Commit Message

If commit message was provided in arguments:
- If no role prefix, auto-prepend:
  - `front` -> `feat(front): ...` (default prefix; if message starts with `fix:` etc., use `fix(front): ...`)
  - `backend` -> `feat(backend): ...`
  - `qa` -> `test(qa): ...`
  - `claude` -> `chore(claude): ...`

If no message:
- View `git diff --cached --stat` and generate a one-line message.

#### 5-2. Execute Commit

```bash
git commit -m "$(cat <<'EOF'
{prefix}({role}): {message}

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

If commit fails (pre-commit hook, etc.) -> output error and abort. No auto-retry.

### Step 6: Push via PR

Parallel worktrees share `origin/main`. Use PR-based merge (see `.claude/rules/worktree-parallel.md` §PR-Based Push):

```bash
BRANCH=$(git branch --show-current)

# 1. Rebase on main
git fetch origin main
if ! git rebase origin/main; then
  echo "Rebase conflict — invoke /resolve-conflict"
  echo "Conflicting files:"
  git diff --name-only --diff-filter=U
  exit 1
fi

# 2. Push worktree branch
git push origin "$BRANCH" --force-with-lease

# 3. Create PR
gh pr create --base main --head "$BRANCH" \
  --title "{commit message}" \
  --body "Auto-created from worktree \`$BRANCH\`" 2>/dev/null || true

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

**On rebase conflict**:
1. Do not auto-abort. Invoke `/resolve-conflict` skill.
2. If the skill succeeds, resume from step 2 (push branch + PR).
3. If the skill STOPs, emit its report and hand to user.

**On merge failure**: STOP. PR is left open for manual review. Do not force merge.

**`--force-with-lease`** is allowed only for pushing to the worktree's own branch (after rebase). `--force` is never allowed.

### Step 7: Output Result

```
## Role-Scoped Commit & Push Result

| Item | Value |
|------|-------|
| Role | {role} |
| Branch | {branch} |
| Commit | {short-hash} {message} |
| Files | {N} |

### Staged Files
- {file1}
- {file2}
- ...

### Push
Pushed to origin/{branch}
```

---

## Error Scenario Summary

| Scenario | Action |
|----------|--------|
| Missing/invalid role argument | Error message and abort |
| Ongoing merge/rebase | Error message and abort |
| Existing staged files contain out-of-scope | Show file list and abort (no unstage) |
| No changed files in role scope | Info message and exit |
| Out-of-scope file found in final verification | Abort (no commit) |
| Pre-commit hook failure | Error output and abort |
| Push failure (no upstream) | Retry with `push -u origin <branch>` |
| Push failure (other) | Error output and abort, `--force` forbidden |

---

## Notes

- This skill has **side effects** (commit + push). Always verify staged files before execution.
- Staging/committing/pushing another role's changes is never allowed.
- `docs/**` is excluded for all roles. Commit docs changes manually.
- `--force` push is never used under any circumstances.
