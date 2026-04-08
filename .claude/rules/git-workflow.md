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

## Branch Naming

- Slice: `slice-{NN}`
- Fix: `fix/{description}`
- Refine: `refine/{description}`

## Forbidden

- Force push to main
- Bypass hooks with `--no-verify`
- Commit secrets, keys, or `.env` with real values
- Meaningless commit messages
