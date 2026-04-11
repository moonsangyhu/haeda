# Git Workflow

## Conventional Commits

Format: `<type>(<scope>): <subject>`

| Type | Purpose |
|------|---------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Code restructuring (no behavior change) |
| `test` | Test additions or modifications |
| `docs` | Documentation |
| `chore` | Maintenance, dependencies, config |
| `style` | Formatting (no logic change) |

Rules:
- Subject: max 50 chars, imperative mood, lowercase
- Body: explain *what* and *why*, wrap at 72 chars

## Session Naming

- Slice work: `claude -n slice-{NN}-{layer}` (e.g., `slice-04-backend`)
- Parallel worktree: `claude --worktree slice-{NN} -n slice-{NN}`
- See `docs/worktree-runbook.md` for detailed rules

## Direct Push to Main (No PR, Rebase-Retry)

This is a solo project. All commits go directly to `main`. Do NOT create branches or PRs.

Because work runs in parallel worktrees, **bare `git push` is forbidden** — two worktrees may race for `origin/main`. Always use the rebase-retry loop defined in `.claude/rules/worktree-parallel.md`:

```bash
git add <specific files>
git commit -m "<message>"

# rebase-retry push — never bare push
git fetch origin main
git rebase origin/main || { git rebase --abort; echo "rebase conflict — STOP"; exit 1; }
git push origin main   # on non-fast-forward, retry fetch+rebase+push up to 3 times
```

**This rule is absolute** — no feature branches, no PRs, no `gh pr create`. Ever.

**Rebase conflict = STOP.** It means the worktree role contract was violated. Report the conflicting files and hand to the user. Never auto-resolve, never `--force`.

## Forbidden

- Creating branches or PRs
- Force push to main
- Bypass hooks with `--no-verify`
- Commit secrets, keys, or `.env` with real values
- Meaningless commit messages
