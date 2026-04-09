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

## Direct Push to Main (No PR)

This is a solo project. All commits go directly to `main`. Do NOT create branches or PRs.

```bash
git add <specific files>
git commit -m "<message>"
git push origin main
```

**This rule is absolute** — no feature branches, no PRs, no `gh pr create`. Ever.

## Forbidden

- Creating branches or PRs
- Force push to main
- Bypass hooks with `--no-verify`
- Commit secrets, keys, or `.env` with real values
- Meaningless commit messages
