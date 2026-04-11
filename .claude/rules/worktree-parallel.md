# Worktree Parallel Strategy

All parallel work on this repository runs through git worktrees. Multiple worktrees may push to `origin/main` concurrently. This document defines the conflict-avoidance contract that every agent and skill MUST follow.

## Three Conflict Surfaces

| # | Surface | Mitigation |
|---|---------|-----------|
| 1 | Two worktrees modify the same file | **Path isolation by role** |
| 2 | Two worktrees push to `origin/main` simultaneously | **Rebase-retry push loop** |
| 3 | Two worktrees rebuild Docker compose at the same time | **Deployer lockfile** |

## Worktree Role Contract

Every worktree declares exactly one role. The role is fixed for the lifetime of the worktree.

| Role | Worktree name pattern | Allowed paths (hard boundary) |
|------|----------------------|------------------------------|
| `backend` | `backend-*`, `slice-NN-backend`, `fix-*-backend` | `server/**` |
| `front` | `front-*`, `slice-NN-front`, `fix-*-front` | `app/**` |
| `qa` | `qa-*` | `app/test/**`, `server/tests/**` |
| `claude` | `claude`, `claude-*` | `.claude/**`, `CLAUDE.md` |

A worktree in role X MUST NOT modify files outside role X's allowed paths. This is enforced at commit time by `/role-scoped-commit-push`.

**Detection**: agents can detect their role by the current worktree directory name (`git rev-parse --show-toplevel | xargs basename`). If the name doesn't match a pattern, agents MUST ask the user rather than guess.

## Shared Directories (filename-scoped, not path-scoped)

Four directories are writable from any role because they hold cross-cutting records. Collisions are prevented by **filename convention**, not path exclusion.

| Directory | Filename convention | Written by |
|-----------|--------------------|-----------|
| `impl-log/` | `{type}-{slug}-{role}.md` | doc-writer |
| `test-reports/` | `{slug}-{role}-test-report.md` | doc-writer, qa-reviewer |
| `docs/reports/` | `YYYY-MM-DD-{role}-{slug}.md` | doc-writer |
| `docs/` (top) | — never writable — | — |

`{role}` MUST be one of `backend`, `front`, `qa`, `claude`.
`{slug}` is lowercase hyphenated, max 40 chars.

Because every filename embeds the role, two worktrees never write the same file — rebase will always fast-forward.

Existing files without role suffix are grandfathered (do not rename). New files MUST follow the convention.

## Rebase-Retry Push Loop

Every push to `origin/main` MUST use this sequence instead of a bare `git push`. The push target is always `HEAD:main` — never a named branch — because worktrees are typically checked out on a branch like `worktree-claude`, `worktree-backend`, etc., not on `main` itself.

```bash
push_with_rebase() {
  local max_retries=3
  local attempt=0
  while [ $attempt -lt $max_retries ]; do
    git fetch origin main
    if ! git rebase origin/main; then
      git rebase --abort 2>/dev/null
      echo "Rebase conflict detected — STOP and report to user"
      return 1
    fi
    if git push origin HEAD:main; then
      return 0
    fi
    attempt=$((attempt + 1))
    echo "Push rejected (non-fast-forward), retry $attempt/$max_retries"
    sleep 1
  done
  echo "Push failed after $max_retries retries"
  return 1
}
```

`HEAD:main` pushes the current commit onto the remote `main` ref regardless of what local branch name the worktree uses. This is the canonical form for worktree-based parallel work on a single shared remote branch.

Why this always works under the role contract:
- Path isolation + filename convention guarantee no overlapping changes.
- Rebase applies cleanly because the commits touch disjoint files.
- The only failure mode is a race where a third worktree pushes between our fetch and push — the retry loop catches that.

**Rebase conflict = contract violation.** If rebase ever fails, an agent or human broke role isolation. STOP, report the conflicting files, and hand to the user. Do NOT attempt auto-resolution.

Forbidden flags: `--force`, `--force-with-lease`, `--no-verify`. Never.

## Deployer Lockfile

Only one `deployer` agent may rebuild Docker or run the iOS simulator at a time. Coordination uses a filesystem lock at the repo root.

Lock path: `.deployer.lock` (gitignored). Contents: `{worktree-name} {pid} {timestamp}`.

Lock acquisition (`deployer` does this at the start of every run):

```bash
acquire_deploy_lock() {
  local lock=".deployer.lock"
  local timeout=1800  # 30 min max wait
  local waited=0
  while [ -e "$lock" ]; do
    # Check if holder is still alive
    local holder_pid=$(awk '{print $2}' "$lock" 2>/dev/null)
    if [ -n "$holder_pid" ] && ! kill -0 "$holder_pid" 2>/dev/null; then
      echo "Stale lock from dead pid $holder_pid — removing"
      rm -f "$lock"
      break
    fi
    if [ $waited -ge $timeout ]; then
      echo "Deploy lock timeout after ${timeout}s, holder: $(cat $lock)"
      return 1
    fi
    sleep 5
    waited=$((waited + 5))
  done
  echo "$(basename $(git rev-parse --show-toplevel)) $$ $(date +%s)" > "$lock"
}

release_deploy_lock() {
  rm -f .deployer.lock
}
```

Always release in both success and failure paths. `.deployer.lock` MUST be in `.gitignore`.

Consequence: parallel worktrees share a single docker compose stack. Last-deploy-wins for the running runtime. Each worktree still builds and tests in its own filesystem, so correctness is unaffected — only the live local instance is shared.

## Agent Responsibilities

| Agent | Worktree rules it enforces |
|-------|---------------------------|
| `product-planner` | Read-only; no worktree concern |
| `spec-keeper` | Read-only; no worktree concern |
| `backend-builder` | Must run inside a `backend`-role worktree; writes only `server/**` |
| `flutter-builder` | Must run inside a `front`-role worktree; writes only `app/**` |
| `ui-designer` | Must run inside a `front`-role worktree; writes only `app/**` |
| `code-reviewer` | Read-only; no worktree concern |
| `qa-reviewer` | Read-only; may write under `test-reports/` with role suffix |
| `debugger` | Read-only; no worktree concern |
| `deployer` | Acquire `.deployer.lock` before any build, release after. Detect and report stale locks. |
| `doc-writer` | Embed worktree role in every filename (`impl-log/`, `test-reports/`, `docs/reports/`) |

If a builder detects it is NOT inside a worktree matching its role, it MUST STOP and report. No cross-worktree patching.

## Per-Worktree Startup Ritual

Before starting work in any worktree, agents or Main should run:

```bash
# 1. Confirm worktree role
basename "$(git rev-parse --show-toplevel)"

# 2. Sync with upstream main
git fetch origin main
git rebase origin/main  # must succeed cleanly; if not, the previous session left state

# 3. Check deployer lock status (informational)
[ -e .deployer.lock ] && cat .deployer.lock || echo "No deploy in progress"
```

If step 2 fails, STOP and ask the user — the worktree is in an unexpected state.

## Summary (Golden Rules)

1. **One role per worktree.** Never cross role boundaries.
2. **Every shared-directory filename embeds the role.** Never write `impl-log/foo.md` — write `impl-log/feat-foo-backend.md`.
3. **Push via rebase-retry loop only.** Never bare `git push`.
4. **Deploy via lockfile.** Never run `docker compose up --build` outside the deployer agent.
5. **Rebase conflict = STOP.** Never auto-resolve.
