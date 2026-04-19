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

## PR-Based Merge to Main

모든 코드 반영은 **PR 생성 → 자동 머지**로 수행한다. `git push origin HEAD:main` 직접 푸시는 금지.

```bash
git add <specific files>
git commit -m "<message>"

# PR via push_via_pr (see .claude/rules/worktree-parallel.md)
# 1. rebase on main
# 2. push worktree branch
# 3. gh pr create → gh pr merge
# 4. if merge fails → STOP
```

**자동 머지 실패 = STOP.** PR을 열어둔 채 사용자에게 보고한다. 강제 머지하지 않는다.

**Rebase conflict = STOP.** `/resolve-conflict` 스킬로 해결 시도 후, 성공하면 PR 플로우 재개.

## Forbidden

- `git push origin HEAD:main` (직접 main 푸시)
- Force push (`--force`)
- Bypass hooks with `--no-verify`
- Commit secrets, keys, or `.env` with real values
- Meaningless commit messages
