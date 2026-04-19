---
name: resolve-conflict
description: Lossless git rebase conflict resolution for worktree parallel work. Merges both sides' changes without dropping functionality. Invoked by /commit, /role-scoped-commit-push, and builder agents when rebase-retry fails. Aborts to user on any semantic ambiguity — never auto-discards a side.
user_invocable: true
---

# Resolve Conflict — Lossless Rebase Conflict Resolution

**Goal**: When two worktrees' commits touch the same file region, merge them so BOTH features/fixes survive. Never discard a side wholesale. Never use `-X theirs`. Never `--force`. When in doubt, STOP with an explicit report and hand to the user.

**Invariant**: Running this skill must never reduce the functionality that either side was trying to add. If the merged result passes fewer tests than either side alone, the skill has failed and must abort.

## Prerequisites

This skill assumes you are mid-rebase with conflicts — it does NOT start a rebase. Typical entry:

- `git rebase origin/main` just failed with CONFLICT markers
- `git status` shows "rebase in progress" and lists unmerged files

If you are NOT in rebase state, STOP immediately — do not invent work.

## Phase 0: Safety Check

Run:
```bash
git status
```

Verify:
1. `interactive rebase in progress` or `rebase in progress` is present
2. At least one file is listed with `both modified` / `both added` / similar
3. No merge-in-progress state simultaneously (if both, STOP — too ambiguous)

Snapshot rollback reference:
```bash
git rev-parse ORIG_HEAD || echo "ORIG_HEAD missing — will use git reflog for rollback"
```

If resolution later fails, `git rebase --abort` restores the worktree.

## Phase 1: Enumerate Conflicts

```bash
git diff --name-only --diff-filter=U
git status --porcelain | grep -E '^(UU|AA|DU|UD|AU|UA)'
```

| Status | Meaning | Handling |
|--------|---------|----------|
| `UU` | both modified | Phase 2 sub-classification |
| `AA` | both added (same path) | Additive merge if disjoint, dedupe if identical |
| `DU` | deleted by us, modified by them | **STOP** — deletion vs live edit is semantic |
| `UD` | modified by us, deleted by them | **STOP** — deletion vs live edit is semantic |
| `AU`/`UA` | unmerged add | **STOP** — review manually |

Record the full list. Even one STOP file triggers Phase 4.

## Phase 2: Per-File Analysis

For each `UU`/`AA` file, gather full context before editing:

```bash
git show :1:<file> > /tmp/rc-base-<n>.txt    # common ancestor
git show :2:<file> > /tmp/rc-ours-<n>.txt    # our commit being replayed
git show :3:<file> > /tmp/rc-theirs-<n>.txt  # origin/main (new base)
```

Read all three plus:
- `git log --oneline -5 -- <file>` (both refs if possible)
- Relevant `impl-log/` entries: `Grep pattern="<file>" path="impl-log/"` — understand what each side was trying to achieve
- Any `docs/reports/` entry mentioning the file

### Sub-Classification

| Pattern | Action |
|---------|--------|
| Both sides added disjoint functions/fields/imports/routes | **Additive merge** — include both |
| Both sides added the exact same line/block | **Deduplicate** — keep one copy |
| Both sides modified the same line, intents orthogonal (e.g. one renamed a variable, the other added a parameter to the same call) | **Synthesized merge** — write combined line by hand so both intents survive |
| Both sides modified the same line with conflicting intents (both set same config to different values, both implemented same function differently) | **STOP** — real semantic conflict |
| One side refactored structure (moved/renamed symbol) while the other edited inside | **STOP** — refactor collision |
| Conflict hunk crosses a function boundary (both sides changed function shape) | **STOP** — too risky for auto-merge |

When you cannot confidently classify, treat as STOP. Err on the side of user involvement.

## Phase 3: Apply Resolution (auto-resolvable files only)

For each file you classified as auto-resolvable:

1. Open the file (it still has `<<<<<<<`, `=======`, `>>>>>>>` markers).
2. For each conflict hunk, rewrite according to classification:
   - **Additive**: include both hunks. Order rationally — alphabetical for imports, source order for methods, earliest-defined for data.
   - **Deduplicate**: keep exactly one copy.
   - **Synthesized**: hand-craft the combined line(s). Quote the original ours/theirs in a comment only if the combination is non-obvious, then delete the comment if it states the obvious.
3. Remove EVERY conflict marker. Verify:
   ```bash
   grep -n '<<<<<<<\|=======\|>>>>>>>' <file>
   ```
   Must return nothing. If any remain, you missed a hunk — loop back.
4. Stage: `git add <file>`

For files classified as STOP, do NOT touch them. Leave the conflict markers intact so the user can see the raw state.

## Phase 4: Early Abort on Any STOP

If **any** file was classified as STOP:

1. Do NOT `git rebase --continue`.
2. Do NOT stage the STOP files.
3. Emit the STOP report (see Output Format).
4. Leave the repo in rebase-in-progress state so the user can inspect `git status`.
5. Return control to the caller with failure status.

Partial wins are OK: files you already auto-resolved stay staged. The user just has to resolve the STOP files and run `git rebase --continue`.

## Phase 5: Per-Language Syntax Check

For every auto-resolved file, run a fast syntax check before continuing the rebase:

| Extension | Check | Failure action |
|-----------|-------|----------------|
| `.py` | `python -m py_compile <file>` | Abort |
| `.dart` | `cd app && dart analyze <file>` (file-scoped) | Abort |
| `.json` | `python -c "import json,sys; json.load(open(sys.argv[1]))" <file>` | Abort |
| `.yaml`, `.yml` | `python -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" <file>` if PyYAML present | Abort on parse error only |
| `.md`, `.txt`, `.gitignore`, `.env.example` | none | — |
| Other | none | — |

If any check fails, the auto-merge produced invalid code. Do NOT continue. Run:
```bash
git rebase --abort
```
Then emit a STOP report citing the failed file.

## Phase 6: Continue the Rebase

```bash
git rebase --continue
```

Three possible outcomes:

1. **Rebase finishes** → proceed to Phase 7.
2. **Next commit has its own conflicts** → rebase pauses again. Loop back to Phase 1 for the new conflict set. Max 5 iterations of the whole skill — beyond that, STOP (the rebase is too tangled for auto-merge).
3. **Rebase errors** (e.g. unknown state) → STOP, emit raw git output in the report.

## Phase 7: Post-Resolution Verification

After the rebase finishes, run the affected-area test suite. This is the only way to prove no functionality was dropped.

- Python files touched → `cd server && uv run pytest -v --tb=short`
- Dart files touched → `cd app && flutter analyze && flutter test`
- Both → run both
- Config-only (.claude/, .gitignore, docs/reports/, impl-log/) → skip the test run, but do `git log --oneline -5` to confirm the merged commits are present

If any test that existed on BOTH sides (ours and theirs) fails after the merge, the merge dropped functionality — that is the failure mode this skill exists to prevent. Roll back:

```bash
git reset --hard ORIG_HEAD
```

Then emit a STOP report with the failing test output. The user must resolve manually.

If tests pass, conflict resolution is complete. Return control to the caller — the caller should resume its PR push flow (push branch + create PR + merge).

## Output Format

### On Success
```
## Conflict Resolution Complete

### Auto-resolved files (N)
- `{file}` — {additive | dedupe | synthesized}
  - ours: {1-line summary of our intent}
  - theirs: {1-line summary of their intent}
  - merged: {1-line summary of how the merge preserves both}

### Syntax checks
- `{file}`: pass

### Tests
- Backend: {N passed, M failed} (or skipped)
- Frontend: {N passed, M failed} (or skipped)

### Rebase
- Commits replayed: {N}
- Final HEAD: {short hash}

### Next
Rebase complete. Caller should re-run the push step:
  git push origin $BRANCH --force-with-lease && gh pr merge ... (see worktree-parallel.md §PR-Based Push)
```

### On STOP
```
## Conflict Resolution STOPPED

### Auto-resolved (staged, N)
- `{file}` — {classification}
...

### Needs manual resolution (M)
- `{file}` — reason: {conflicting intents | refactor collision | DU | UD | crossed function boundary | syntax check failed | test regression}
  - ours (hunk):
    ```
    {quoted conflict hunk from side 2}
    ```
  - theirs (hunk):
    ```
    {quoted conflict hunk from side 3}
    ```
  - Why auto-merge is unsafe: {specific reason}

### Repo state
Rebase still in progress. To resolve manually:
  1. Edit the files above, combining both sides' intent.
  2. Verify no conflict markers remain: grep -n '<<<<<<<' <file>
  3. git add <file>
  4. git rebase --continue

Or to abort the rebase and return to ORIG_HEAD:
  git rebase --abort
```

## Never Do

- Never use `git checkout --theirs <file>` or `--ours <file>` as a blanket strategy — those discard one side's intent wholesale.
- Never run `git rebase -X theirs origin/main` or `-X ours` — same reason.
- Never `git reset --hard` outside Phase 7 rollback or user-confirmed abort.
- Never force-push after resolution.
- Never claim success without running Phase 7 tests.
- Never edit files classified as STOP.
- Never skip Phase 5 (syntax check) or Phase 7 (tests).
- Never resolve more than 5 sequential conflict iterations without STOP — deep tangles require human judgment.

## When Agents Invoke This Skill

Agents and skills must invoke this skill when `git rebase origin/main` fails with conflicts:

- `/commit` (Step 3-2 and Step 4 push loops)
- `/role-scoped-commit-push` (Step 6 push loop)
- `/set` (manual push fallback)
- `/rollback` (impl-log commit push)
- `backend-builder` Phase 0 origin/main sync
- `flutter-builder` Phase 0 origin/main sync
- `deployer` if it encounters an interrupted rebase from prior work

**Invocation form for subagents**: Read this file (`.claude/skills/resolve-conflict/SKILL.md`) and follow the phases in order. Do not skip phases. Do not modify the procedure.

**Invocation form for Main thread**: Call via the Skill tool (`Skill(skill: "resolve-conflict")`) or follow the file directly.
