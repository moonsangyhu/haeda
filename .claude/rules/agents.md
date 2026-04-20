# Agent Team

All implementation, review, build, and documentation work uses an 11-agent team. Main (Opus) handles requirement parsing, orchestration, and the final commit/push only.

모델 배정은 `.claude/rules/model-policy.md` 에 정의된 **Plan=Opus / Implementation=Sonnet** 정책을 따른다.

| Agent | Model | Role | Scope |
|-------|-------|------|-------|
| `product-planner` | **Opus** | Requirement → executable feature spec (planning) | read-only (docs + code) |
| `spec-keeper` | Sonnet | **Pre-implementation** plan validation against docs source of truth | read-only |
| `backend-builder` | Sonnet | FastAPI implementation (TDD 의무) | server/ only |
| `flutter-builder` | Sonnet | Flutter UI implementation (TDD 의무) | app/ only |
| `ui-designer` | Sonnet | UI design / polish / accessibility | app/ only |
| `spec-compliance-reviewer` | Sonnet | **Post-implementation** spec compliance review (diff vs Feature Plan) | read-only + bash (git diff) |
| `code-reviewer` | Sonnet | Static code quality gate (style, reuse, security, TDD evidence) | read-only + bash (git diff) |
| `qa-reviewer` | Sonnet | Test execution + checklist review + verification-before-completion | read-only + bash |
| `debugger` | Sonnet | Deep cross-layer debugging (systematic-debugging skill): reproduce → layer analysis → fix plan → execute (TDD) → verify → report | read+edit+bash within worktree role |
| `deployer` | Sonnet | Docker rebuild, flutter ios simulator run, health check (verified evidence) | bash only |
| `doc-writer` | Sonnet | impl-log, test-reports, docs/reports/ + retrospective section | write to impl-log/, test-reports/, docs/reports/ only |

## Dispatch Rules

Feature work (new feature, enhancement) follows this chain — each arrow is a mandatory handoff:

```
product-planner → spec-keeper → (backend-builder ∥ flutter-builder with TDD)
  → spec-compliance-reviewer → code-reviewer → qa-reviewer
  → [debugger (systematic-debugging) if QA fails] → deployer → doc-writer(+retrospective) → Main /commit
```

Fix work (bug fix, no spec change) skips product-planner and spec-keeper:

```
debugger (systematic-debugging) → (backend-builder | flutter-builder with TDD)
  → spec-compliance-reviewer → code-reviewer → qa-reviewer
  → deployer → doc-writer(+retrospective) → Main /commit
```

Detailed rules:

- **Brainstorming (pre-planning)**: 사용자 요청이 러프하면 `product-planner` 에이전트가 `brainstorming` 스킬로 먼저 shaping 요청. 구체적 spec 이 될 때까지 Feature Plan 을 생성하지 않는다.
- **Planning**: All feature requests start with `product-planner`. The main thread never plans directly. product-planner 는 **Phase 0: Prior-Work Lookup** 의무 — 작업 시작 전 `docs/reports/` 에서 관련 과거 보고서를 Grep·Read 해 Feature Plan 의 `### Referenced Reports` 섹션에 인용한다 (`.claude/rules/regression-prevention.md`). Use `spec-keeper` immediately after to validate the plan (pre-implementation).
- **Implementation**: Delegate to `backend-builder` and/or `flutter-builder`. 모든 builder 는 `tdd` 스킬을 준수하고 completion output 에 `### TDD Cycle Evidence` 를 포함한다. 또한 **Phase 0.5: Reports Lookup** 의무로 `### Referenced Reports` 섹션도 필수. `feature` role 워크트리에서는 둘 다 순차 실행 가능 (같은 워크트리, 레이어 분리 불필요).
- **Design**: UI/UX improvements go to `ui-designer` first, then `flutter-builder` integrates.
- **Spec Compliance Review (post-implementation)**: After every builder completion, spawn `spec-compliance-reviewer` **before** `code-reviewer`. 이 에이전트는 구현 diff 가 Feature Plan 의 acceptance criteria / endpoint / screen / field 와 정확히 일치하는지 검증한다. Mismatch 시 해당 builder 재호출 (max 1 retry).
- **Code Review**: After `spec-compliance-reviewer` passes, spawn `code-reviewer`. 이 에이전트는 품질 (스타일, 중복, 보안, TDD 증거) 만 본다. 변경 요구 시 builder 재호출 (max 1 retry).
- **QA**: After `code-reviewer` passes, spawn `qa-reviewer` to run tests + checklist. qa-reviewer 는 `verification-before-completion` 스킬을 따라 모든 주장에 명령/출력 인용 필수.
- **Debug**: If `qa-reviewer` returns `partial` or `incomplete`, auto-spawn `debugger`. The debugger performs deep cross-layer analysis (FE/BE/DB), plans, executes in-role fixes, writes handoff specs for other roles, verifies by re-reproduction, and generates a 3-file debug report (impl-log + test-report + docs/reports) following the doc-writer procedure. Main routes handoff specs to the matching builder and re-runs qa-reviewer (max 2 retries).
- **Deploy**: After QA complete, spawn `deployer` for rebuild + health check + iOS simulator run.
- **Documentation**: After deploy succeeds, spawn `doc-writer` for impl-log + test-report + feature report.
- **Commit & PR Merge**: Only after doc-writer completes, main thread runs `/commit` skill (creates PR → auto-merges to main).
- **Conflict Resolution**: When any rebase fails with a git conflict, invoke `/resolve-conflict` skill per `.claude/skills/resolve-conflict/SKILL.md`. Never `git rebase --abort` without first trying this skill.
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
2. Create PR and auto-merge to main (see `.claude/rules/worktree-parallel.md` §PR-Based Push)
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
| Spec Verify (Step 2, pre-impl) | spec-keeper finds zero mismatches | Re-run product-planner once, then STOP |
| Spec Compliance (Step 4.5, post-impl) | spec-compliance-reviewer verdict = Pass (no Missing / no Drift) | Re-invoke builder with fix list (max 1 retry) |
| Code Review (Step 5) | code-reviewer verdict = Pass (품질 + TDD 증거 포함) | Re-invoke builder with fix list (max 1 retry) |
| Regression Prevention (Step 5 sub-gate) | builder/debugger completion output 에 `### Referenced Reports` 섹션 존재 + (기존 파일 수정/삭제 시 관련 보고서 인용) — `.claude/rules/regression-prevention.md` | Re-invoke builder with instruction to Grep `docs/reports/` and cite (max 1 retry) |
| QA (Step 6) | qa-reviewer verdict = complete (verification-before-completion 통과) | Spawn debugger (systematic-debugging) → builder (TDD) → re-QA (max 2 retries) |
| Deploy (Step 7) | health check passes + simulator running (모든 주장 명령/출력 인용) | STOP, report to user with logs |
| Document (Step 8) | doc-writer writes all 3 files with retrospective section, without touching source-of-truth docs | STOP, report protected-file violation or missing retrospective |
| Commit (Step 9) | all above passed | — |
