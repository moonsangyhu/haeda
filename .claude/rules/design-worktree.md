# Design Worktree

The design worktree is the "design studio" for Haeda. Its only job is to produce design documents — UI specs, interaction flows, color palettes, layout diagrams, pixel art specifications — that other worktrees can later implement. It is NOT a place to write, edit, test, build, or deploy code.

## Activation

A worktree becomes a design worktree when `.design-worktree` (an empty, gitignored sentinel file) exists at its repo root. The file is worktree-local.

```bash
# Arm:    touch .design-worktree
# Disarm: rm .design-worktree
```

The dedicated design worktree for this repo is `.claude/worktrees/design` on branch `worktree-design`.

## Hard Boundary

In a design worktree, Write / Edit / NotebookEdit is **blocked** for any path outside `docs/design/**`. This is enforced by `.claude/hooks/design-guard.sh` as a PreToolUse hook — there is no escape hatch.

| Path | Design may edit? |
|------|-------------------|
| `docs/design/**` | yes |
| `app/**`, `server/**` | **no** — code belongs in front/backend worktrees |
| `.claude/**`, `CLAUDE.md` | **no** — config belongs in claude-role worktree |
| `docs/prd.md`, `docs/user-flows.md`, etc. | **no** — source-of-truth docs require user approval |
| `docs/planning/**` | **no** — planning belongs in planner worktree |
| `docs/reports/**`, `impl-log/**`, `test-reports/**` | **no** |

## What the Design Worktree Does

1. Researches design references (web search, image analysis, competitor review).
2. Creates design documents at `docs/design/<slug>.md` — screen layouts, color palettes, pixel art specs, interaction patterns, component breakdowns.
3. Produces detailed enough specs that `ui-designer` and `flutter-builder` agents in a front worktree can implement without ambiguity.
4. Commits and pushes design docs (standard rebase-retry push; design only ever touches `docs/design/**`, so rebase is trivial).

It does NOT:

- Write Flutter/Dart code, FastAPI code, or any source code.
- Run builders, QA, deployer, or simulators.
- Modify configs, hooks, rules, or skills.
- Touch source-of-truth docs.

## Design Document Structure

Every file under `docs/design/` SHOULD start with:

```yaml
---
slug: miniroom-cyworld
status: draft        # draft | ready | implemented | dropped
created: 2026-04-18
area: front          # front | backend | full-stack
---
```

`status: ready` means the design is complete and a front/backend worktree can implement it.

## Handoff to Implementation

When a design doc reaches `status: ready`, the front worktree reads it and implements. The front worktree may update the status to `implemented` after completion.

## Related Files

- Enforcement hook: `.claude/hooks/design-guard.sh`
- Source-of-truth guard (still active): `.claude/hooks/docs-guard.sh`
- Worktree role matrix: `.claude/rules/worktree-parallel.md`
- Planner worktree (similar pattern): `.claude/rules/planner-worktree.md`
