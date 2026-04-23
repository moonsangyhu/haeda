# Haeda — AIDLC Workflow

Haeda is a collaborative challenge app (calendar-based motivation service) for a 4-week hospital pilot MVP. Stack: Flutter (app/) + FastAPI (server/) + PostgreSQL + Kakao OAuth.

As of 2026-04-23 this project uses the **AI-DLC adaptive workflow** from [awslabs/aidlc-workflows](https://github.com/awslabs/aidlc-workflows) as its primary development methodology. Legacy feature-flow infrastructure is archived under `.claude/{agents,skills,rules}/ARCHIVE/`.

Activation phrase: start development requests with `Using AI-DLC, ...`

---

# PRIORITY: This workflow OVERRIDES all other built-in workflows

## Entry Point (MANDATORY)

On any software-development request the AI MUST:

1. Read `.aidlc-rule-details/core-workflow.md` — the full workflow specification, ~539 lines. This is the single source of truth for phase order, stage gating, and approval flow. Treat it as equivalent to inline content in this file.
2. Load the common rules listed in that file (`common/process-overview.md`, `common/session-continuity.md`, `common/content-validation.md`, `common/question-format-guide.md`).
3. Scan `.aidlc-rule-details/extensions/` for `*.opt-in.md` files and load their rule siblings on user opt-in; for extension directories WITHOUT an `*.opt-in.md` file (i.e., `haeda-*`), load the rule file immediately and enforce always.
4. Display the welcome message from `common/welcome-message.md` once per new workflow.
5. Log every user input and AI response in `aidlc-docs/audit.md` with ISO 8601 timestamps per the audit format in core-workflow.md. Never overwrite audit.md — append only.

## Phase Overview (summary; full rules in core-workflow.md)

| Phase | Stages | Gating |
|-------|--------|--------|
| 🔵 Inception (WHAT/WHY) | Workspace Detection (always) → Reverse Engineering (brownfield) → Requirements Analysis (always, adaptive depth) → User Stories (conditional) → Workflow Planning (always) → Application Design (conditional) → Units Generation (conditional) | Explicit user approval at end of each stage |
| 🟢 Construction (HOW) | Per-unit loop: Functional Design → NFR Requirements → NFR Design → Infrastructure Design → Code Generation, then Build and Test (after all units) | 2-option completion message per stage: "Request Changes" or "Continue" |
| 🟡 Operations | Placeholder | — |

**NO EMERGENT BEHAVIOR**: use the standardized 2-option message only. Never invent 3+ option menus.

## Rule Details Loading

Rule details path resolution order (use the first that exists):
- `.aidlc/aidlc-rules/aws-aidlc-rule-details/`
- `.aidlc-rule-details/` ← **canonical for this project**
- `.kiro/aws-aidlc-rule-details/`
- `.amazonq/aws-aidlc-rule-details/`

All references in core-workflow.md (e.g., `inception/requirements-analysis.md`) are relative to the resolved directory.

## Extensions (MANDATORY loading rules)

Load all `extensions/*/*.opt-in.md` at workflow start. Keep full rule files unloaded until the user opts in during Requirements Analysis. Extensions WITHOUT `.opt-in.md` are always-enforced and MUST be loaded at start.

Always-enforced in this project:

| Extension | Path | Applies to | Purpose |
|-----------|------|-----------|---------|
| `haeda-tdd` | `extensions/haeda-tdd/haeda-tdd.md` | Code Generation | RED → GREEN → REFACTOR + pytest/flutter test evidence |
| `haeda-local-build` | `extensions/haeda-local-build/haeda-local-build.md` | Build and Test | `docker compose up --build -d backend` + `curl /health` |
| `haeda-flutter-ios-sim` | `extensions/haeda-flutter-ios-sim/haeda-flutter-ios-sim.md` | Build and Test | `flutter build ios --simulator` + terminate/uninstall/install/launch |
| `haeda-domain-context` | `extensions/haeda-domain-context/haeda-domain-context.md` | Inception + Construction | English identifiers / Korean UX, API envelope, error codes, season icons, size limits, MVP scope |

Non-compliance with any always-enforced extension is a **blocking finding** — the stage MUST NOT present completion until resolved.

## Plan-Level Checkbox Enforcement

- Every plan file uses `- [ ]` / `- [x]` checkboxes.
- Mark `[x]` IMMEDIATELY in the same interaction the step completes.
- Also update stage status in `aidlc-docs/aidlc-state.md` at the same time.
- No exceptions.

## Content Validation

Before writing any file, validate per `common/content-validation.md` + `common/ascii-diagram-standards.md`: Mermaid syntax, escape special characters, ASCII diagram fidelity, text alternatives for visual content.

## Directory Structure

```text
<workspace-root>/
├── app/                       # Flutter
├── server/                    # FastAPI
├── aidlc-docs/                # AIDLC artifacts (auto-generated)
│   ├── aidlc-state.md         # phase/stage/extension state
│   ├── audit.md               # append-only user+AI log
│   ├── inception/
│   │   ├── plans/  reverse-engineering/  requirements/
│   │   └── user-stories/  application-design/
│   ├── construction/
│   │   ├── plans/
│   │   ├── {unit}/functional-design/  nfr-requirements/  nfr-design/  infrastructure-design/  code/
│   │   └── build-and-test/
│   └── operations/            # placeholder
├── docs/
│   ├── ARCHIVE/               # legacy prd/user-flows/domain-model/api-contract (read-only)
│   └── reports/               # ad-hoc worktree reports (retained)
├── .aidlc-rule-details/       # upstream rules + haeda extensions
└── .claude/                   # Claude Code config (hooks, archived agents/skills/rules)
```

**CRITICAL**: application code lives at the workspace root (`app/`, `server/`), NEVER inside `aidlc-docs/`.

---

# Haeda-Specific Addendum

This section layers project-local constraints on top of the generic AIDLC workflow. AIDLC wins if anything conflicts.

## Project Context

- **Product**: Collaborative calendar-based challenge motivation app (hospital pilot MVP).
- **Timeline**: 4-week hospital pilot MVP. P0 features only; P1+ on explicit user request.
- **Stack**: Flutter 3 (app/), FastAPI + SQLAlchemy 2.0 async (server/), PostgreSQL, Kakao OAuth, Docker Compose local env.
- **Source of truth docs (pre-AIDLC)**: Archived at `docs/ARCHIVE/`. The new single source of truth is `aidlc-docs/inception/reverse-engineering/` + `aidlc-docs/inception/requirements/`, generated by the first brownfield Inception run.

## 언어 정책 (Language Policy) — MANDATORY

사용자는 한국어로 명령한다. **모든 산출물 문서는 한국어로 작성**한다. 내부 작업(tool call, shell 명령, 경로, reasoning)은 영어 허용.

**한국어 필수**:
- `aidlc-docs/inception/**` 및 `aidlc-docs/construction/**` 의 모든 산출물 (requirements / user-stories / application-design / functional-design / NFR / code summary / build-and-test)
- `aidlc-docs/audit.md` — 사용자 입력은 원문 그대로, AI 응답 요약은 한국어
- `aidlc-docs/aidlc-state.md` 의 상태 설명 (upstream 필드명은 영어 허용)
- `docs/reports/**`
- AIDLC stage 완료 메시지 · 질문 파일의 질문·선택지 (선택 문자 A/B/C 는 영어)
- Commit 메시지 (conventional commits scope 는 영어: `feat(claude): ...`)
- PR 제목·본문

**영어 유지**:
- `.aidlc-rule-details/common|inception|construction|operations|extensions/security|extensions/testing/**` — upstream 파일. **번역 금지**.
- 코드 식별자 (클래스·함수·변수·API 경로·DB 테이블) — `haeda-domain-context` DOMAIN-01.
- 에러 코드 `UPPER_SNAKE_CASE` (사용자에게 노출되는 `message` 는 한국어).
- 핵심 섹션 헤더 (`# INCEPTION PHASE`, `## Workspace Detection` 등 upstream 참조 대상).

**위반 시**: AIDLC stage 가 영어로 산출물을 작성하면 Extension Compliance 에 `language-policy: non-compliant` 기록 후 stage 블록. 사용자 답변을 AI 가 영어로 옮겨 적으면 blocking finding.

## Retained Utilities

AIDLC phase 외부에서도 호출 가능한 도구:
- `.claude/skills/commit/` — stage/commit/push with conventional commits
- `.claude/skills/resolve-conflict/` — lossless rebase conflict resolution
- `.claude/skills/smoke-test/` — local env smoke check
- `.claude/skills/local/` — docker compose lifecycle
- `.claude/hooks/secret-scanner.sh` — always-on credential scanner
- `.claude/hooks/bash-guard.sh` — destructive command guard
- `.claude/hooks/docs-guard.sh` — `docs/ARCHIVE/**` read-only 보호
- `.claude/hooks/push-gate.py` — `gh pr merge` 시 `aidlc-docs/audit.md` approval 검증 + 직접 main push 차단

## Deprecated (archived, do NOT invoke)

- `.claude/agents/ARCHIVE/` — 11 legacy agents (product-planner, backend/flutter-builder, qa-reviewer 등)
- `.claude/skills/ARCHIVE/` — feature-flow, plan-feature, slice-planning, fix, tdd skill 등
- `.claude/rules/ARCHIVE/` — workflow.md, agents.md, worktree-parallel.md 등
- `docs/ARCHIVE/` — prd / user-flows / domain-model / api-contract / old CLAUDE.md
- Legacy references in user prompts / memory: 역사적 맥락으로만 취급, AIDLC 플로우로 진행.

## Worktrees

`.claude/worktrees/{claude,feature,design,planner,debug}` 물리 디렉토리는 병렬 작업용 git 격리로 유지. AIDLC 는 worktree-role 개념이 없으므로 어느 워크트리든 어느 phase 든 실행 가능. 세션 시작 시 `git fetch origin main && git rebase origin/main` 하고 PR 로만 main 에 반영.

## Git Workflow

- main 반영은 `gh pr create` + `gh pr merge`. 직접 push 금지.
- Conventional commits: `<type>(<scope>): <한글 subject>`
- `--force` / `--no-verify` 금지.
- Rebase conflict 는 `/resolve-conflict` skill 로 해결 시도 후 재진행.

## Rollback

Migration 이전 상태 태그: `pre-aidlc-migration`. 전체 복원: `git reset --hard pre-aidlc-migration`.
