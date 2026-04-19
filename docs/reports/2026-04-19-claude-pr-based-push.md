# Feature Report: PR-Based Push Workflow

- Date: 2026-04-19
- Worktree: claude
- Role: claude
- Area: config (rules, skills, agents, hooks)
- Status: complete

## Request

git main에 직접 push하지 않고, PR 생성 → 자동 머지로 전환. 자동 머지 실패 시 강제하지 않고 STOP.

## Root Cause / Context

기존 워크플로우는 `git push origin HEAD:main`으로 직접 main에 push했다. PR 기반 머지로 전환하면 코드 리뷰 기록이 남고, 머지 충돌 시 안전하게 중단할 수 있다.

## Actions

### New Push Flow (replaces rebase-retry)

```
1. git rebase origin/main
2. git push origin $BRANCH --force-with-lease
3. gh pr create --base main
4. gh pr merge --merge --delete-branch=false
5. (실패 시 STOP, PR 열어둔 채 보고)
6. git fetch origin main && git rebase origin/main
```

### Modified Files (16개)

| Category | Files |
|----------|-------|
| Core rules | `git-workflow.md`, `worktree-parallel.md` |
| Skills | `commit/SKILL.md`, `role-scoped-commit-push/SKILL.md`, `resolve-conflict/SKILL.md`, `rollback/SKILL.md`, `set/SKILL.md`, `implement-planned/SKILL.md`, `plan-feature/SKILL.md` |
| Rules | `agents.md`, `autonomous-execution.md`, `claude-config-sync.md`, `design-worktree.md`, `planner-worktree.md` |
| Agents | `debugger.md`, `doc-writer.md` |
| Hooks | `push-gate.py` |

### Key Changes

- `worktree-parallel.md`: `push_with_rebase()` → `push_via_pr()` 전체 교체
- `git-workflow.md`: "No PR" → "PR-Based Merge to Main"
- `push-gate.py`: `git push` 감지 → `gh pr merge` 감지로 전환 (branch push는 허용)
- `--force-with-lease`: main에는 금지, 워크트리 자기 브랜치에만 허용 (rebase 후 push에 필요)

## QA Results

- 구조적 검증: 16개 파일 모두 `HEAD:main` 직접 push 제거 확인
- grep으로 잔여 `HEAD:main` 참조 확인 → 금지 문구/설명에만 남아있음 (정상)

## Follow-ups

- 다른 워크트리의 기존 세션은 재시작 필요 (최신 skill/rule 적용)
- GitHub repo에 branch protection rule 설정 시 PR 머지 정책 일관성 확인

## Related

- 이전 작업: 2026-04-19-claude-design-spec-handoff.md
