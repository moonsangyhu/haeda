---
name: plan-feature
description: In the planner worktree, shape a feature idea into a ready-to-implement spec at docs/planning/specs/<slug>.md. Use when the user describes an idea to bank for later.
allowed-tools: "Read Write Edit Glob Grep Bash"
argument-hint: "[slug] [short description]"
---

# Plan Feature

Authoring helper for the planner worktree. Turns a user-described idea into a filled-out spec using `docs/planning/TEMPLATE.md` and commits it.

## Preconditions

- Current worktree MUST be a planner worktree (`.planner-worktree` sentinel at repo root). If not, STOP and tell the user to run this from the planner worktree.
- `docs/planning/TEMPLATE.md` must exist.

## Usage

```
/plan-feature verification-reminder "push notification nudge when user hasn't verified today"
/plan-feature                # no args — ask user for slug + description via AskUserQuestion
```

Argument: `$ARGUMENTS` (first token = slug, rest = description).

---

## Execution Steps

### 1. Verify planner worktree

```bash
test -f .planner-worktree || { echo "STOP: not a planner worktree"; exit 1; }
```

### 2. Gather inputs

If `$ARGUMENTS` is empty, use AskUserQuestion to collect:
- slug (lowercase-hyphenated, max 40 chars)
- one-sentence description
- area (front / backend / full-stack)
- priority (P0 / P1 / P2)

If a slug was given, check `docs/planning/specs/<slug>.md` and `docs/planning/ideas/<slug>.md` — if either exists, ask the user whether to overwrite, edit, or pick a new slug.

### 3. Read source-of-truth context (read-only)

Before drafting, read the parts of these files that look relevant to the idea:
- `docs/prd.md` — scope + priority context
- `docs/user-flows.md` — screens/flows the feature touches
- `docs/domain-model.md` — entities that would change
- `docs/api-contract.md` — endpoints that would change

Do NOT edit any of these. They are source-of-truth.

### 4. Draft the spec

Copy `docs/planning/TEMPLATE.md` to `docs/planning/specs/<slug>.md`. Fill every section based on the user's description and the docs you just read. Rules:

- Front-matter `status: ready` only if every section is filled AND there are no blocking open questions. Otherwise use `status: idea` and save to `docs/planning/ideas/<slug>.md` instead.
- Section 5 (API / domain deltas) must cite the specific `docs/api-contract.md` or `docs/domain-model.md` section that needs updating. Do not edit those files — flag the need.
- Section 6 (acceptance criteria) must be testable. If you cannot write a test for a criterion, refine it or drop it.
- Section 7 (open questions) must be empty or each question must be answerable by the user in a single sentence.

### 5. Show the draft

Print a short summary (title, status, area, priority, top 3 acceptance criteria). Ask the user: "저장할까요? (save / edit / cancel)"

- save → proceed to step 6
- edit → apply the user's edits and reshow
- cancel → delete the draft file, stop

### 6. Commit and push

Only if the user said "save":

```bash
git add docs/planning/specs/<slug>.md   # or docs/planning/ideas/<slug>.md
git commit -m "plan(<slug>): add feature spec"
# rebase-retry push (see .claude/rules/worktree-parallel.md)
git fetch origin main
git rebase origin/main || { git rebase --abort; echo "rebase conflict — STOP"; exit 1; }
git push origin HEAD:main
```

Report the commit SHA and the path to the new spec.

## Post-conditions

- Spec exists at `docs/planning/specs/<slug>.md` (or `ideas/<slug>.md`) with valid front-matter.
- Commit is on `origin/main`.
- User is told how to implement it later: "In a feature worktree, run `/implement-planned` to pick this up."
