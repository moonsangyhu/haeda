# Agent Team

All implementation, review, build, and documentation work uses a 10-agent team. Main (Opus) handles requirement parsing, orchestration, and the final commit/push only.

| Agent | Model | Role | Scope |
|-------|-------|------|-------|
| `product-planner` | Sonnet | Requirement → executable feature spec | read-only (docs + code) |
| `spec-keeper` | Sonnet | Plan/code validation against docs source of truth | read-only |
| `backend-builder` | Sonnet | FastAPI implementation | server/ only |
| `flutter-builder` | Sonnet | Flutter UI implementation | app/ only |
| `ui-designer` | Sonnet | UI design / polish / accessibility | app/ only |
| `code-reviewer` | Sonnet | Static code quality gate (style, reuse, security smells) | read-only + bash (git diff) |
| `qa-reviewer` | Sonnet | Test execution + checklist review | read-only + bash |
| `debugger` | Sonnet | Root-cause diagnosis, emits fix spec for builder | read-only + bash |
| `deployer` | Sonnet | Docker rebuild, flutter ios simulator run, health check | bash only |
| `doc-writer` | Sonnet | impl-log, test-reports, docs/reports/ | write to impl-log/, test-reports/, docs/reports/ only |

## Dispatch Rules

Feature work (new feature, enhancement) follows this chain — each arrow is a mandatory handoff:

```
product-planner → spec-keeper → (backend-builder ∥ flutter-builder)
  → code-reviewer → qa-reviewer → [debugger if QA fails] → deployer → doc-writer → Main /commit
```

Fix work (bug fix, no spec change) skips product-planner and spec-keeper:

```
debugger → (backend-builder | flutter-builder) → code-reviewer → qa-reviewer
  → deployer → doc-writer → Main /commit
```

Detailed rules:

- **Planning**: All feature requests start with `product-planner`. The main thread never plans directly. Use `spec-keeper` immediately after to validate.
- **Implementation**: Delegate to `backend-builder` and/or `flutter-builder`. Cross-layer = run both in parallel.
- **Design**: UI/UX improvements go to `ui-designer` first, then `flutter-builder` integrates.
- **Code Review**: After every builder completion, spawn `code-reviewer` before `qa-reviewer`. If verdict is `Changes Requested`, re-invoke the owning builder with the fix list (max 1 retry), then re-review.
- **QA**: After `code-reviewer` passes, spawn `qa-reviewer` to run tests + checklist.
- **Debug**: If `qa-reviewer` returns `partial` or `incomplete`, auto-spawn `debugger` to diagnose → hand off fix spec to builder → re-run qa-reviewer (max 2 retries).
- **Deploy**: After QA complete, spawn `deployer` for rebuild + health check + iOS simulator run.
- **Documentation**: After deploy succeeds, spawn `doc-writer` for impl-log + test-report + feature report.
- **Commit & Push**: Only after doc-writer completes, main thread runs `/commit` skill.
- **Rollback**: When user requests rollback/undo, run `/rollback` skill.
- **Main (Opus)**: Requirement parsing, agent orchestration, final /commit. Do NOT implement, test, build, or document directly.

## Build Verification (Mandatory)

Builder agents MUST run a full build as the final step of their own execution — analyze/test alone is insufficient.

| Agent | Required Build Command |
|-------|----------------------|
| `flutter-builder` | `cd app && flutter build ios --simulator` |
| `backend-builder` | `cd server && docker compose build` or `python -m py_compile` |

- **flutter-builder는 반드시 iOS simulator 빌드**를 사용한다. `flutter build web`은 검증으로 인정하지 않는다.
- If a build fails, the agent must fix the error and rebuild before reporting completion.
- Do NOT report "implementation complete" without a passing build.

**Simulator run 확인**은 이제 `deployer` 에이전트가 담당한다. Main(Opus)은 deployer 리포트의 "Simulator: running" 항목만 확인하면 된다. Main 이 직접 `flutter run` 을 실행하지 않는다.

## Post-Implementation (Mandatory)

After `doc-writer` completes, Main (Opus) MUST run `/commit` to:
1. Stage & commit changes (code + impl-log + test-report + docs/reports)
2. Push directly to main (no branches, no PRs)
3. Confirm impl-log exists (doc-writer already wrote it)

Do NOT stop after "deploy success" — the cycle is: **plan → spec verify → implement → review → qa → [debug if needed] → deploy → document → commit → push**.

## Implementation Log (`impl-log/`)

Every feature/fix gets a detailed log file at `impl-log/<slug>.md`.
- Created by `doc-writer` agent during Step 7 of feature-flow
- Referenced by `/rollback` skill to know what to undo
- Agents MUST read relevant impl-logs before modifying previously implemented features

## Gate Rules Summary

| Gate | Condition | Action on Fail |
|------|-----------|----------------|
| Spec Verify (Step 2) | spec-keeper finds zero mismatches | Re-run product-planner once, then STOP |
| Code Review (Step 4) | code-reviewer verdict = Pass | Re-invoke builder with fix list (max 1 retry) |
| QA (Step 5) | qa-reviewer verdict = complete | Spawn debugger → builder → re-QA (max 2 retries) |
| Deploy (Step 6) | health check passes + simulator running | STOP, report to user with logs |
| Document (Step 7) | doc-writer writes all 3 files without touching source-of-truth docs | STOP, report protected-file violation |
| Commit (Step 8) | all above passed | — |
