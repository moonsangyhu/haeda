# Planner Worktree

The planner worktree is the "idea bank" for Haeda. Its only job is to shape feature ideas into implementable specs that other worktrees can later consume. It is NOT a place to write, edit, test, build, or deploy code.

## Activation

A worktree becomes a planner worktree when `.planner-worktree` (an empty, gitignored sentinel file) exists at its repo root. The file is worktree-local, so only the worktrees you explicitly arm are planners.

```bash
# Arm:    touch .planner-worktree
# Disarm: rm .planner-worktree
```

The dedicated planner worktree for this repo is `.claude/worktrees/planner` on branch `worktree-planner`, following the same pattern as `.claude/worktrees/{claude,debug,feature}`. Start a session there with `cd .claude/worktrees/planner && claude`.

## Hard Boundary

In a planner worktree, Write / Edit / NotebookEdit is **blocked** for any path outside `docs/planning/**`. This is enforced by `.claude/hooks/planner-guard.sh` as a PreToolUse hook — there is no escape hatch for "just this once".

| Path | Planner may edit? |
|------|-------------------|
| `docs/planning/**` | yes |
| `docs/prd.md`, `docs/user-flows.md`, `docs/domain-model.md`, `docs/api-contract.md` | **no** (docs-guard also blocks) |
| `docs/reports/**` | **yes** — 본 워크트리의 작업 결과서 작성용 (`worktree-task-report.md` 의무). 필요 시 `docs/reports/YYYY-MM-DD-planner-<slug>.md` 로 기록 |
| `impl-log/**`, `test-reports/**` | **no** |
| `app/**`, `server/**` | **no** |
| `.claude/**`, `CLAUDE.md`, `.gitignore`, top-level configs | **no** — move to a `claude`-role worktree |

If you need to change rules, hooks, skills, or code, switch to the appropriate role worktree. The planner worktree stays strictly in the idea-bank lane.

## What the Planner Worktree Does

1. Captures ideas in `docs/planning/ideas/<slug>.md` (rough, unshaped).
2. Promotes ready ideas to `docs/planning/specs/<slug>.md` using `docs/planning/TEMPLATE.md`, with front-matter `status: ready`.
3. Commits and pushes those plan docs (standard PR-based push; planner only ever touches `docs/planning/**`, so rebase is always trivial).

It does NOT:

- Run builders, QA, deployer, or simulators.
- Run `/feature-flow`, `/fix`, or `/commit` for code.
- Modify source-of-truth docs (`docs/prd.md`, etc.) — those still require explicit user approval and a different worktree.

## Lifecycle of a Plan

```
docs/planning/ideas/<slug>.md
        │  (shape, refine)
        ▼
docs/planning/specs/<slug>.md   status: ready
        │  (feature worktree runs /implement-planned)
        ▼
docs/planning/specs/<slug>.md   status: in-progress
        │  (implementation + QA + deploy completes in feature worktree)
        ▼
docs/planning/archive/<slug>.md  status: done
```

Status transitions after `ready` happen **in the feature worktree**, not the planner worktree. Feature worktrees have full write access to `docs/planning/**` — the planner-guard only arms the *planner* side. This is intentional: the hand-off is one-way.

## Spec Front-matter

Every file under `docs/planning/specs/` MUST start with:

```yaml
---
slug: verification-reminder
status: ready        # idea | ready | in-progress | done | dropped
created: 2026-04-12
area: front          # front | backend | full-stack
priority: P0         # P0 | P1 | P2
---
```

The `/implement-planned` skill in feature worktrees filters by `status: ready`.

## Related Files

- Enforcement hook: `.claude/hooks/planner-guard.sh`
- Source-of-truth guard (still active): `.claude/hooks/docs-guard.sh`
- Authoring helper skill: `.claude/skills/plan-feature/SKILL.md`
- Consumer skill (feature worktrees): `.claude/skills/implement-planned/SKILL.md`
- Spec template: `docs/planning/TEMPLATE.md`
- Worktree role matrix: `.claude/rules/worktree-parallel.md`
