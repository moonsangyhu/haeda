---
name: implement-planned
description: In a feature worktree, list ready-to-implement specs from docs/planning/specs/ and hand one to the feature-flow pipeline. Use when the user says "지난번에 계획한 기능 구현해" or similar.
allowed-tools: "Read Write Edit Glob Grep Bash Skill"
argument-hint: "[slug]"
---

# Implement Planned Feature

Feature-worktree-side consumer of the planner idea bank. Picks a `status: ready` spec from `docs/planning/specs/` and hands it to `feature-flow` for full implementation.

## Preconditions

- Current worktree MUST NOT be the planner (`.planner-worktree` sentinel MUST be absent). If the sentinel exists, STOP — implementation cannot run from a planner worktree.
- Current worktree SHOULD be a `front`, `backend`, or generic feature worktree (e.g., `.claude/worktrees/feature`).
- `docs/planning/specs/` must contain at least one spec with `status: ready`.

## Usage

```
/implement-planned                       # list ready specs, ask which one
/implement-planned verification-reminder # implement this specific slug
```

Argument: `$ARGUMENTS` (optional slug).

---

## Execution Steps

### 1. Refuse to run in planner worktree

```bash
if [ -f .planner-worktree ]; then
  echo "STOP: this is a planner worktree. Switch to a feature worktree (e.g. .claude/worktrees/feature) and rerun."
  exit 1
fi
```

### 2. Sync with origin

```bash
git fetch origin main
git rebase origin/main || { git rebase --abort; echo "rebase conflict — STOP and ask user"; exit 1; }
```

### 3. Collect ready specs

Glob `docs/planning/specs/*.md`. For each file, read the front-matter block and keep only those with `status: ready`. Extract `slug`, `area`, `priority`, and the first heading.

If `$ARGUMENTS` is provided:
- Match the given slug exactly. If no match or the match is not `status: ready`, STOP and list what IS ready.

If no argument:
- If exactly one ready spec exists, use it.
- If multiple, use AskUserQuestion to let the user pick. Sort by priority (P0 first), then by `created` date ascending.
- If zero, STOP and report "No ready specs in docs/planning/specs/. Run /plan-feature in the planner worktree first."

### 4. Flip status to in-progress

Edit the selected spec's front-matter: `status: ready` → `status: in-progress`. Stage and commit immediately:

```bash
git add docs/planning/specs/<slug>.md
git commit -m "plan(<slug>): mark in-progress"
# PR merge (see .claude/rules/worktree-parallel.md §PR-Based Push)
BRANCH=$(git branch --show-current)
git push origin "$BRANCH" --force-with-lease
gh pr create --base main --head "$BRANCH" --title "plan(<slug>): status update" --body "auto" 2>/dev/null || true
PR_NUM=$(gh pr view "$BRANCH" --json number -q .number)
gh pr merge "$PR_NUM" --merge --delete-branch=false || { echo "Merge failed — STOP"; exit 1; }
git fetch origin main && git rebase origin/main
```

This claim is a lightweight lock — other worktrees won't pick up the same spec mid-flight.

### 5. Hand off to feature-flow

Read the spec fully. Construct a product-planner input from sections 1–6 (Problem, User behavior, Scope, Affected files, API/domain deltas, Acceptance criteria). Invoke the existing `feature-flow` skill with that input:

```
Skill(feature-flow, "<spec title>\n\n<rendered sections>")
```

`feature-flow` runs the standard 9-step pipeline (product-planner → spec-keeper → builders → code-review → QA → deploy → doc-writer → commit). Do NOT bypass any step.

### 6. On feature-flow success — archive the spec

After `feature-flow` reports completion (deploy success + commit pushed):

```bash
# Flip status and move
python3 -c "..."   # or sed -E 's/^status: in-progress/status: done/'
git mv docs/planning/specs/<slug>.md docs/planning/archive/<slug>.md
git commit -m "plan(<slug>): mark done and archive"
# PR merge (see .claude/rules/worktree-parallel.md §PR-Based Push)
BRANCH=$(git branch --show-current)
git push origin "$BRANCH" --force-with-lease
gh pr create --base main --head "$BRANCH" --title "plan(<slug>): status update" --body "auto" 2>/dev/null || true
PR_NUM=$(gh pr view "$BRANCH" --json number -q .number)
gh pr merge "$PR_NUM" --merge --delete-branch=false || { echo "Merge failed — STOP"; exit 1; }
git fetch origin main && git rebase origin/main
```

Write a pointer line in `impl-log/feat-<slug>-<role>.md` referencing `docs/planning/archive/<slug>.md` as the originating spec.

### 7. On feature-flow failure

Do NOT archive. Leave the spec at `status: in-progress` so the user can diagnose, fix, and retry. Report which stage failed and surface the relevant log.

## Notes

- Feature worktrees are allowed to write to `docs/planning/**` because neither `planner-guard.sh` (sentinel absent here) nor `docs-guard.sh` (explicit `docs/planning/**` exception) blocks them.
- Rebase conflicts during the status flips usually mean two workers are trying to implement the same spec. STOP and ask the user — do not force.
- If the spec's section 7 (Open Questions) is non-empty, STOP before step 4 and ask the user to resolve them. Do not guess answers during implementation.
