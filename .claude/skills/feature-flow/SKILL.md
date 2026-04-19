---
name: feature-flow
description: Enforced workflow for all feature work. 9 steps: plan → spec verify → implement → code review → qa → [debug] → deploy → document → commit. Every step is delegated to a specialist agent; Main only orchestrates and runs the final commit.
user_invocable: true
disable_model_invocation: true
---

# Feature Flow — Agent-Orchestrated Feature Workflow

All feature work MUST follow this 9-step workflow. No step may be skipped.

**Auto-proceed mode**: All steps run end-to-end without user approval gates. STOP only when: spec verify fails twice, code review fails twice, QA fails twice after debug loop, deploy fails, or doc-writer hits a protected-file violation.

**Prime rule — Main does not implement, review, test, build, or write docs directly.** Main parses the requirement, spawns the right agent, reads the agent's output, and spawns the next agent. Every execution step runs inside a subagent (Sonnet).

## Model Strategy

| Phase | Executor | Model |
|-------|----------|-------|
| Step 0 (Parse requirement) | Main | Opus |
| Step 1 (Plan) | `product-planner` | Sonnet |
| Step 2 (Spec verify) | `spec-keeper` | Sonnet |
| Step 3 (Implement) | `backend-builder` / `flutter-builder` (parallel) | Sonnet |
| Step 4 (Code review) | `code-reviewer` | Sonnet |
| Step 5 (QA) | `qa-reviewer` | Sonnet |
| Step 5b (Debug, conditional) | `debugger` → builder | Sonnet |
| Step 6 (Deploy) | `deployer` | Sonnet |
| Step 7 (Document) | `doc-writer` | Sonnet |
| Step 8 (Commit & Push) | Main + `/commit` | Opus |
| Step 9 (Final output) | Main | Opus |

Argument: `<requirement description>`

---

## Step 0: Parse Requirement & Gather Design Context (Main)

Main reads the user's requirement, normalizes it to a single sentence, and identifies any obvious red flags (P1 scope, spec conflict, missing info). If info is missing, ask the user BEFORE spawning any agent.

**Design spec discovery**: Scan `docs/design/*.md` for files with `status: ready` whose content is relevant to the requirement. If a matching design spec exists, read it and include its full content in the Step 1 prompt to product-planner. This ensures design intent (layout, interaction, visual specs) flows into the feature plan without builders needing to discover it independently.

```
# Example: passing design context to product-planner
Agent(product-planner, "
  Requirement: {requirement}

  Design spec (docs/design/{slug}.md):
  {full design spec content}

  Plan this feature. The design spec above contains UI layout, interaction,
  and visual details — incorporate them into the Frontend Plan section.
")
```

If no relevant design spec exists, proceed without it. Otherwise auto-proceed to Step 1.

---

## Step 1: Plan (product-planner)

Spawn `product-planner` with the requirement. The agent produces an executable feature spec including:
- Acceptance Criteria
- Affected Area (frontend / backend / both)
- Backend Plan / Frontend Plan
- Reusable existing code pointers

Print a one-line summary from the agent's output. Auto-proceed to Step 2.

---

## Step 2: Spec Verify (spec-keeper)

Spawn `spec-keeper` with the feature plan from Step 1 pasted into the prompt. The agent compares the plan against `docs/prd.md`, `user-flows.md`, `domain-model.md`, `api-contract.md`.

| Result | Action |
|--------|--------|
| Zero mismatches | Auto-proceed to Step 3 |
| Warnings only (P1/Open Question) | STOP and ask user |
| Mismatches | Re-spawn `product-planner` with the mismatch list (max 1 retry). If it fails again, STOP. |

---

## Step 3: Implement (backend-builder / flutter-builder)

Based on the feature plan's Affected Area:

- **Backend only**: Spawn `backend-builder`.
- **Frontend only**: Spawn `flutter-builder`.
- **Both**: Spawn `backend-builder` and `flutter-builder` **in parallel** (single message, two Agent calls).

Pass the relevant portion of the Step 1 plan (Backend Plan or Frontend Plan sections) into each agent's prompt.

Each builder agent is responsible for:
- Its own tests (pytest / flutter test)
- Its own build (flutter build ios --simulator / docker compose build)
- Reporting changed files

Rules:
- No subagent may modify `docs/`
- No subagent may touch the other layer
- No subagent may run git commit, add, or push

If a builder fails its own build, it must self-correct before reporting. If it cannot, it reports the failure and we STOP.

---

## Step 4: Code Review (code-reviewer)

Spawn `code-reviewer` with the builder completion outputs from Step 3.

| Verdict | Action |
|---------|--------|
| **Pass** | Auto-proceed to Step 5 |
| **Changes Requested** | Re-spawn the owning builder with the blocking-issues list, then re-run code-reviewer (max 1 retry). If still Changes Requested, STOP. |

---

## Step 5: QA (qa-reviewer)

Spawn `qa-reviewer` with:
- Acceptance criteria from Step 1
- Changed files from Step 3
- Code review verdict from Step 4

The agent runs `pytest`, `flutter test`, `flutter analyze`, and the checklist review.

| Verdict | Action |
|---------|--------|
| **Complete** | Auto-proceed to Step 6 |
| **Partial / Incomplete** | Auto-enter Step 5b (debug loop) |

---

## Step 5b: Debug Loop (debugger → builder → re-QA)

Conditional step — only runs when Step 5 returns partial/incomplete.

1. Spawn `debugger` with the failing test output and qa-reviewer verdict. The agent produces a **fix spec** naming the owning builder.
2. Spawn the owning builder (`backend-builder` or `flutter-builder`) with the fix spec.
3. Re-spawn `qa-reviewer`.

Max 2 retries of the full 5b loop. After 2 failed retries, STOP and hand to user with the last debug report.

---

## Step 6: Deploy (deployer)

Spawn `deployer`. The agent:
- Detects affected area via git diff
- Rebuilds Docker services (`docker compose up --build -d <service>`)
- Runs `flutter build ios --simulator` + `flutter run -d <simulator-id>` for frontend changes
- Verifies `/health` and simulator boot

| Verdict | Action |
|---------|--------|
| **Success** | Auto-proceed to Step 7 |
| **Failed** | STOP, print deployer logs, hand to user |

---

## Step 7: Document (doc-writer)

Spawn `doc-writer` with:
- Feature plan from Step 1
- Builder outputs from Step 3
- Code review verdict from Step 4
- QA verdict from Step 5
- Deploy report from Step 6

The agent writes:
- `impl-log/<slug>.md`
- `test-reports/<slug>-test-report.md`
- `docs/reports/YYYY-MM-DD-<slug>.md`

If doc-writer reports a protected-file violation (attempted to touch `docs/prd.md` etc.), STOP — the plan was wrong.

---

## Step 8: Commit & Push (Main + /commit)

Main runs `/commit` to:
1. Stage code changes (from Step 3) + documentation (from Step 7)
2. Commit with a conventional-commits message
3. Push directly to main

Commit is forbidden before Step 7 completes. Push is forbidden before commit.

Cross-layer commits use `/role-scoped-commit-push` separately for `backend` and `front` roles.

---

## Step 9: Final Output (Main)

Print the completion summary:

```
## Feature Flow Complete

| Item | Value |
|------|-------|
| Feature | {summary} |
| Area | {frontend / backend / both} |
| Plan | product-planner ✓ |
| Spec verify | spec-keeper ✓ |
| Implementation | {backend-builder / flutter-builder} ✓ |
| Code review | code-reviewer ✓ |
| QA | qa-reviewer: complete |
| Debug loop | {N retries | skipped} |
| Deploy | deployer: backend health OK, simulator running |
| Documentation | impl-log + test-report + feature report |
| Commit | {hash} |
| Push | done |
```

---

## Guardrails

These rules apply at ALL steps:

- **Main never implements, tests, builds, reviews, or writes docs directly.** Always spawn the specialist agent.
- **P0/P1 scope**: Do not implement features beyond P1. product-planner blocks P1 silently; spec-keeper is the enforcement gate.
- **Spec match**: Code must match `docs/api-contract.md` paths, field names, error codes exactly.
- **No source-of-truth doc edits**: Never modify `docs/prd.md`, `docs/user-flows.md`, `docs/domain-model.md`, `docs/api-contract.md`. Only `docs/reports/` is writable, and only by doc-writer.
- **Cross-boundary prohibition**: `flutter-builder` never touches `server/`. `backend-builder` never touches `app/`.
- **Plan first**: Never start implementation without a product-planner plan validated by spec-keeper.
- **QA before deploy**: Never deploy without qa-reviewer verdict "complete".
- **Deploy before document**: Never write docs without a successful deploy report.
- **Document before commit**: Never commit before doc-writer writes impl-log + test-report + feature report.
- **Auto-proceed**: All steps run without user approval. STOP only on: spec verify double failure, code review double failure, QA double failure after debug loop, deploy failure, or protected-file violation.

---

## 미완료 복구

feature-flow가 중간에 중단된 경우(세션 종료, 에러, 타임아웃, 컨텍스트 소진), **다음 세션에서 Main은 반드시 아래 절차를 따른다:**

### 세션 시작 시 자동 감지

```bash
STAGED=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
UNSTAGED=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
if [ "$STAGED" -gt 0 ] || [ "$UNSTAGED" -gt 0 ]; then
  echo "⚠️ 이전 세션에서 feature-flow가 미완료된 상태입니다"
  echo "   staged: $STAGED, unstaged: $UNSTAGED"
fi
```

워크트리에 staged/unstaged 변경이 있으면 사용자에게 즉시 보고한다.

### 마지막 완료 Step 식별

| 조건 | 마지막 완료 Step | 재개 지점 |
|------|-----------------|-----------|
| staged 변경 있고, 커밋 없음 | Step 3 (구현) | Step 4 (코드 리뷰)부터 |
| 커밋은 있으나 test-report 없음 | Step 5 (QA) | Step 6 (배포)부터 |
| test-report 있으나 impl-log 없음 | Step 6 (배포) | Step 7 (문서)부터 |
| impl-log 있으나 PR 없음 | Step 7 (문서) | Step 8 (커밋)부터 |

### 복구 절차

1. 사용자에게 "feature-flow 미완료 — Step N부터 재개합니다" 선언
2. 해당 Step부터 feature-flow를 재개한다
3. **Step 6 (배포)부터 재시작이 가장 안전** — 빌드+시뮬레이터 확인을 다시 거치므로
