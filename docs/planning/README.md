# docs/planning — Idea Bank

Feature specs and raw ideas live here. This directory is the hand-off point between the **planner worktree** (shapes ideas into specs) and **feature worktrees** (implement specs).

## Layout

```
docs/planning/
├── README.md              # this file
├── TEMPLATE.md            # spec template — copy this when promoting an idea
├── ideas/<slug>.md        # raw, unshaped ideas (free-form)
├── specs/<slug>.md        # ready-to-implement specs (front-matter required)
└── archive/<slug>.md      # implemented or dropped
```

## Spec Front-matter (required for `specs/`)

```yaml
---
slug: verification-reminder
status: ready        # idea | ready | in-progress | done | dropped
created: 2026-04-12
area: front          # front | backend | full-stack
priority: P0         # P0 | P1 | P2
---
```

Only specs with `status: ready` are picked up by `/implement-planned` in feature worktrees.

## Who writes here

| Worktree | Allowed? | Typical action |
|----------|----------|----------------|
| Planner (sentinel armed) | yes, and this is the ONLY place it can write | Draft ideas, promote to specs |
| Feature (front / backend) | yes | Flip status to `in-progress` / `done`, move to `archive/` after implementation |
| Other roles | yes (not restricted), but uncommon | — |

The planner worktree is locked to `docs/planning/**` by `.claude/hooks/planner-guard.sh`. See `.claude/rules/planner-worktree.md`.

## Authoring a new spec (planner worktree)

1. Drop a rough note in `docs/planning/ideas/<slug>.md`.
2. When ready, use `/plan-feature <slug>` or manually copy `TEMPLATE.md` into `docs/planning/specs/<slug>.md`.
3. Fill every section. Cross-reference `docs/api-contract.md` and `docs/domain-model.md` for any new fields/endpoints.
4. Set `status: ready`, commit, push.

## Implementing a spec (feature worktree)

1. `git pull`.
2. Run `/implement-planned` — it lists `status: ready` specs, you pick one.
3. The skill hands the spec to `product-planner` → feature-flow pipeline.
4. On successful commit+deploy, status flips to `done` and the file moves to `archive/`.
