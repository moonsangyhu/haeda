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
| `feature` | `feature`, `feature-*`, `slice-NN` | `app/**`, `server/**` |
| `backend` | `backend-*`, `slice-NN-backend`, `fix-*-backend` | `server/**` |
| `front` | `front-*`, `slice-NN-front`, `fix-*-front` | `app/**` |
| `qa` | `qa-*` | `app/test/**`, `server/tests/**` |
| `claude` | `claude`, `claude-*` | `.claude/**`, `CLAUDE.md` |
| `planner` | `planner`, `.claude/worktrees/planner`, marked by `.planner-worktree` sentinel at repo root | `docs/planning/**` |
| `design` | `design`, `.claude/worktrees/design`, marked by `.design-worktree` sentinel at repo root | `docs/design/**` |

**`feature` role은 full-stack 작업용.** 솔로 개발에서 같은 기능의 front/back을 분리하면 API 계약 동기화, 머지 순서 의존, 리뷰 2배 등 오버헤드만 증가한다. 기능 단위로 워크트리를 나누되, 레이어는 하나의 워크트리에서 함께 작업한다.

A worktree in role X MUST NOT modify files outside role X's allowed paths. This is enforced at commit time by `/role-scoped-commit-push`. For the `planner` role it is additionally enforced at tool-call time by `.claude/hooks/planner-guard.sh`. For the `design` role it is enforced by `.claude/hooks/design-guard.sh`.

**Detection**: agents can detect their role by the current worktree directory name (`git rev-parse --show-toplevel | xargs basename`). If the name doesn't match a pattern, agents MUST ask the user rather than guess. The `planner` role is double-checked by the presence of `.planner-worktree` sentinel at the repo root — the sentinel is the authoritative signal, the name is a hint. See `.claude/rules/planner-worktree.md`. The `design` role uses `.design-worktree` sentinel. See `.claude/rules/design-worktree.md`.

## Shared Directories (filename-scoped, not path-scoped)

Four directories are writable from any role because they hold cross-cutting records. Collisions are prevented by **filename convention**, not path exclusion.

| Directory | Filename convention | Written by |
|-----------|--------------------|-----------|
| `impl-log/` | `{type}-{slug}-{role}.md` | doc-writer |
| `test-reports/` | `{slug}-{role}-test-report.md` | doc-writer, qa-reviewer |
| `docs/reports/` | `YYYY-MM-DD-{role}-{slug}.md` | doc-writer |
| `docs/reports/screenshots/` | `{YYYY-MM-DD}-{role}-{slug}-{NN}.png` | deployer |
| `docs/` (top) | — never writable — | — |

`{role}` MUST be one of `feature`, `backend`, `front`, `qa`, `claude`, `design`, `planner`.
`{slug}` is lowercase hyphenated, max 40 chars.

Because every filename embeds the role, two worktrees never write the same file — rebase will always fast-forward.

Existing files without role suffix are grandfathered (do not rename). New files MUST follow the convention.

## PR-Based Push (PR → Auto-Merge)

모든 코드 반영은 PR 생성 → 자동 머지로 수행한다. `git push origin HEAD:main` 직접 푸시는 금지.

워크트리는 각자의 브랜치(`worktree-claude`, `worktree-backend` 등)에서 작업하고, 해당 브랜치를 remote에 push한 뒤 main으로의 PR을 생성·머지한다.

```bash
push_via_pr() {
  local branch
  branch=$(git branch --show-current)
  local title="${1:-$branch 자동 PR}"
  local body="${2:-자동 생성}"

  # 1. Rebase on main (ensure clean merge)
  git fetch origin main
  if ! git rebase origin/main; then
    echo "Rebase conflict — invoke /resolve-conflict"
    return 1
  fi

  # 2. Push worktree branch (--force-with-lease OK for own branch after rebase)
  git push origin "$branch" --force-with-lease || { echo "Push to branch failed"; return 1; }

  # 3. Create PR (ignore error if PR already exists)
  gh pr create --base main --head "$branch" \
    --title "$title" \
    --body "$body" 2>/dev/null || true

  # 4. Merge PR — if fails, STOP (do not force)
  local pr_number
  pr_number=$(gh pr view "$branch" --json number -q .number 2>/dev/null)
  if [ -z "$pr_number" ]; then
    echo "Failed to find PR for branch $branch — STOP"
    return 1
  fi

  if ! gh pr merge "$pr_number" --merge --delete-branch=false; then
    echo "Auto-merge failed — STOP. PR #$pr_number left open."
    return 1
  fi

  # 5. Sync local with merged main
  git fetch origin main
  git rebase origin/main
  echo "PR #$pr_number merged successfully"
}
```

### PR 작성 규칙

**제목**: 한글, conventional commit 형식. 70자 이내.
```
feat(front): 챌린지 상세 화면 구현
fix(backend): 토큰 검증 로직 수정
chore(claude): 배포 스크린샷 캡처 기능 추가
```

**본문**: 한글, HEREDOC 사용. 아래 템플릿을 따른다.

```bash
gh pr create --base main --head "$BRANCH" \
  --title "<type>(<scope>): <한글 설명>" \
  --body "$(cat <<'EOF'
## 요약
- <무엇을 왜 변경했는지 1-3줄>

## 변경 사항
- `path/file.ext` — 변경 내용
- `path/file2.ext` — 변경 내용

## 테스트
- [ ] <검증 항목 1>
- [ ] <검증 항목 2>

🤖 Generated with [Claude Code](https://claude.ai/code)
EOF
)"
```

**섹션별 가이드:**
- **요약**: "무엇을 왜" — 리뷰어가 3초 안에 맥락을 파악할 수 있도록
- **변경 사항**: 파일 경로 + 한 줄 설명. 구조화된 변경 목록이 리뷰 속도를 높인다
- **테스트**: 체크리스트 형태. 수동/자동 검증 항목 구분
- **Attribution**: 마지막 줄에 Claude Code 표시

**핵심 규칙:**
- 자동 머지 실패 시 PR을 열어둔 채 STOP. 강제 머지하지 않는다.
- `--force-with-lease`는 워크트리 자기 브랜치에만 허용 (rebase 후 push에 필요).
- `--force`는 여전히 절대 금지.
- `--delete-branch=false`: 워크트리 브랜치는 삭제하지 않는다.

**Rebase conflict → invoke `resolve-conflict` skill.** When rebase fails (contract violation, cross-worktree overlap, or shared-file edit), do NOT auto-abort. Instead:

1. Stop at the rebase failure (do not immediately `git rebase --abort`).
2. Read and follow `.claude/skills/resolve-conflict/SKILL.md` phase by phase.
3. If the skill completes successfully, resume from step 2 (push branch + create PR + merge).
4. If the skill STOPs, emit its handoff report to the user.

**Forbidden flags**: `--force` (on any ref), `--no-verify`, `-X theirs`, `-X ours`. Never.

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
| `backend-builder` | Must run inside a `backend` or `feature`-role worktree; writes only `server/**` |
| `flutter-builder` | Must run inside a `front` or `feature`-role worktree; writes only `app/**` |
| `ui-designer` | Must run inside a `front` or `feature`-role worktree; writes only `app/**` |
| `code-reviewer` | Read-only; no worktree concern |
| `qa-reviewer` | Read-only; may write under `test-reports/` with role suffix |
| `debugger` | Read-only; no worktree concern |
| `deployer` | Acquire `.deployer.lock` before any build, release after. Detect and report stale locks. |
| `doc-writer` | Embed worktree role in every filename (`impl-log/`, `test-reports/`, `docs/reports/`) |

If a builder detects it is NOT inside a worktree matching its role (including `feature`), it MUST STOP and report. No cross-worktree patching.

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
