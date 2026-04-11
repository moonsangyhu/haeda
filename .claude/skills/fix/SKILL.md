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

## Step 1: Diagnose (debugger)

Spawn `debugger` with the bug description. The agent:
- Reproduces the bug (test run, curl, log inspection)
- Isolates the root cause with file:line evidence
- Emits a fix spec naming the owning builder

Main reads the fix spec and proceeds to Step 2.

If debugger reports "cannot reproduce" or "insufficient evidence", STOP and ask the user for more info.

---

## Step 2: Fix (backend-builder / flutter-builder)

Spawn the builder named in the debugger's fix spec, passing:
- The fix spec verbatim
- The instruction: "fix only, no refactor, no feature additions"

Cross-layer bugs: spawn both builders in parallel with their respective portions of the fix spec.

Rules:
- Each agent works only in its designated directory
- No agent may modify `docs/`
- No agent may run git commands
- Do not refactor surrounding code
- Do not add features

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

## Step 6: Document (doc-writer)

Spawn `doc-writer` with all prior outputs. The agent writes:
- `impl-log/fix-<slug>.md`
- `test-reports/fix-<slug>-test-report.md`
- `docs/reports/YYYY-MM-DD-fix-<slug>.md`

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
