---
name: fix
description: Lightweight bug fix flow. debugger → builder → code review → QA → deploy → doc-writer → commit. Skips product-planner and spec-keeper (no spec change). Agent-orchestrated, no approval gates.
user_invocable: true
disable_model_invocation: true
---

# Fix — Agent-Orchestrated Bug Fix Flow

Fast-track bug fix workflow. Runs end-to-end without approval gates.

**Prime rule — Main does not diagnose, fix, test, build, or write docs directly.** Every step runs inside a specialist subagent. Main only parses the bug report, spawns agents, and runs `/commit` at the end.

Differences from `feature-flow`:
- Skips `product-planner` and `spec-keeper` (bug fix assumes no spec change)
- Starts with `debugger` instead of `product-planner`
- All other steps (code-reviewer, qa-reviewer, deployer, doc-writer, commit) are identical

### Model Strategy

| Phase | Executor | Model |
|-------|----------|-------|
| Step 0 (Parse bug) | Main | Opus |
| Step 1 (Diagnose) | `debugger` | Sonnet |
| Step 2 (Fix) | `backend-builder` / `flutter-builder` | Sonnet |
| Step 3 (Code review) | `code-reviewer` | Sonnet |
| Step 4 (QA) | `qa-reviewer` | Sonnet |
| Step 4b (Debug retry) | `debugger` → builder | Sonnet |
| Step 5 (Deploy) | `deployer` | Sonnet |
| Step 6 (Document) | `doc-writer` | Sonnet |
| Step 7 (Commit & Push) | Main + `/commit` | Opus |
| Step 8 (Summary) | Main | Opus |

Argument: `<bug description>`

---

## Step 0: Parse Bug (Main)

Main reads the bug report, identifies the affected area (from error messages, logs, or user description), and auto-proceeds. If critical info is missing (no reproduction, no error), ask the user before spawning debugger.

---

## Step 1: Diagnose, Plan, Execute, Verify, Report (debugger)

Spawn `debugger` with the bug description. The agent performs the full deep-debug loop:
1. Reproduce the bug mechanically
2. Trace it layer-by-layer across Frontend → API → Service → Data Access → Database
3. Synthesize a single evidence-backed root cause
4. Write a per-layer fix plan
5. Execute in-role fixes and emit handoff specs for other roles
6. Re-run the reproduction to verify the fix
7. Generate the 3-file debug report (impl-log + test-report + docs/reports) via the doc-writer procedure

Main reads the debugger's output:
- **In-role fixes already applied** — staged, unpushed. Proceed to Step 3 (code review).
- **Handoff specs present** — Step 2 spawns the matching builder agent(s).
- **Cannot reproduce / STOP** — halt the flow and ask the user for more info.

---

## Step 2: Apply Handoff Specs (backend-builder / flutter-builder)

The debugger already applied in-role fixes in Step 1. This step only runs if the debugger emitted handoff specs for layers outside its worktree role.

For each handoff spec, spawn the matching builder agent in its own worktree, passing:
- The handoff spec verbatim (target file, current code, replacement code, regression test)
- The instruction: "fix only, no refactor, no feature additions"

Cross-layer bugs: spawn the relevant builders in parallel.

Rules:
- Each agent works only in its designated worktree role
- No agent modifies `docs/` source of truth
- No agent runs git commands (main thread handles commit/push)
- Do not refactor surrounding code
- Do not add features

If the debugger had no handoff specs (single-role fix), skip this step entirely.

---

## Step 3: Code Review (code-reviewer)

Spawn `code-reviewer` with the builder completion output.

| Verdict | Action |
|---------|--------|
| **Pass** | Auto-proceed to Step 4 |
| **Changes Requested** | Re-spawn the owning builder with the fix list (max 1 retry), then re-review |

---

## Step 4: QA (qa-reviewer)

Spawn `qa-reviewer` with:
- Bug description and root cause from Step 1
- Changed files from Step 2
- Code review verdict from Step 3

| Verdict | Action |
|---------|--------|
| **Complete** | Auto-proceed to Step 5 |
| **Partial / Incomplete** | Auto-enter Step 4b |

---

## Step 4b: Debug Retry (debugger → builder → re-QA)

Conditional — only runs when Step 4 fails.

1. Re-spawn `debugger` with the new failing test output
2. Re-spawn the builder with the updated fix spec
3. Re-spawn `qa-reviewer`

Max 2 retries. After 2 failed retries, STOP and hand to user.

---

## Step 5: Deploy (deployer)

Spawn `deployer`. The agent rebuilds affected services, runs `flutter build ios --simulator` + `flutter run` (if app/ changed), and verifies health.

| Verdict | Action |
|---------|--------|
| **Success** | Auto-proceed to Step 6 |
| **Failed** | STOP, print logs, hand to user |

---

## Step 6: Document (doc-writer or debugger-authored)

If the debugger already wrote the 3-file debug report in Step 1 Phase 7, this step is a no-op — skip to Step 7.

Otherwise (e.g. the bug was fixed purely via handoff-spec builders without the debugger executing), spawn `doc-writer` with all prior outputs. The agent writes:
- `impl-log/fix-<slug>-<role>.md`
- `test-reports/fix-<slug>-<role>-test-report.md`
- `docs/reports/YYYY-MM-DD-<role>-fix-<slug>.md`

---

## Step 7: Commit & Push (Main + /commit)

Main runs `/commit` to stage code + documentation, commit with a `fix:` conventional-commits message, and push to main.

Commit is forbidden before Step 6 completes.

---

## Step 8: Summary (Main)

```
## Bug Fix Complete

| Item | Value |
|------|-------|
| Bug | {description} |
| Root cause | {from debugger} |
| Fix | {what changed} |
| Code review | code-reviewer ✓ |
| QA | qa-reviewer: complete |
| Debug retries | {N | 0} |
| Deploy | deployer: health OK, simulator running |
| Documentation | impl-log + test-report + fix report |
| Commit | {hash} |
| Push | done |
```

---

## Guardrails

- **Main never diagnoses, fixes, tests, builds, reviews, or writes docs directly.** Spawn the specialist agent every time.
- No approval gates — runs fully automatic
- STOP only on: debugger cannot reproduce, code review double failure, QA double failure after debug retry, deploy failure, or protected-file violation
- Do not modify `docs/prd.md`, `docs/user-flows.md`, `docs/domain-model.md`, `docs/api-contract.md` — source of truth
- `docs/reports/`, `impl-log/`, `test-reports/` are writable (doc-writer only)
- Do not add features — fix only
- Do not touch unrelated files
