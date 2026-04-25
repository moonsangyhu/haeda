# superpowers 기본화 구현 Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** haeda 레포의 기본 워크플로우를 superpowers 로 전환. AI-DLC / 11-agent feature-flow / 10-step slice flow / 워크트리 role contract 모두 ARCHIVE 처리하고, 한국어 산출물·로컬 빌드·iOS simulator 정책을 별도 rule + 로컬 스킬로 보존.

**Architecture:** 8 단계 마이그레이션. (1) ARCHIVE 이동 → (2) 유지 파일 stale 참조 cleanup → (3) 신규 rule 4 개 → (4) 신규 로컬 스킬 2 개 → (5) CLAUDE.md 갱신 → (6) settings.json 커밋 → (7) smoke test + 보고서 → (8) force-with-lease push + PR. 코드 변경 없음 (설정·문서·스킬 정의만).

**Tech Stack:** git, Claude Code config (markdown SKILL.md / rules .md), JSON (settings.json), bash.

**Spec:** `docs/superpowers/specs/2026-04-25-superpowers-default-design.md`

**Base:** `pre-aidlc-migration` 태그 (HEAD = `dc99369`). origin/main 보다 4 커밋 뒤.

**Subagent scope rule (MANDATORY):** implementer subagent 는 자기 task 범위 안의 파일만 수정. untracked / unstaged 다른 파일은 절대 reset / delete / move 하지 않는다. controller 가 명시적으로 지시한 경우만 예외.

---

## Task 1A: agents 디렉토리 ARCHIVE 이동

**Files:** Move `.claude/agents/*.md` 11 개 → `.claude/agents/ARCHIVE/`

대상: backend-builder, code-reviewer, debugger, deployer, doc-writer, flutter-builder, product-planner, qa-reviewer, spec-compliance-reviewer, spec-keeper, ui-designer.

- [x] **Step 1**: `mkdir -p .claude/agents/ARCHIVE`
- [x] **Step 2**: `git mv` 11 파일을 ARCHIVE/ 로
- [x] **Step 3**: 검증 — top-level .md 0, ARCHIVE/ 11
- [x] **Step 4**: 커밋 `chore(claude): 11-agent feature-flow archive`

→ commit `45781b1`

---

## Task 1B: 중복 + feature-flow 스킬 ARCHIVE 이동

**Files:** Move `.claude/skills/` 19 개 → `.claude/skills/ARCHIVE/`

중복 (5): tdd, verification-before-completion, systematic-debugging, brainstorming, parallel-subagent-dispatch.
feature-flow (14): feature-flow, fix, slice-planning, plan-feature, implement-planned, implement-design, retrospective, next-slice-planning, qa-remediation, slice-test-report, mvp-slice-check, docs-drift-check, role-scoped-commit-push, rollback.

- [x] **Step 1**: `mkdir -p .claude/skills/ARCHIVE`
- [x] **Step 2**: 중복 5 → ARCHIVE/
- [x] **Step 3**: feature-flow 14 → ARCHIVE/
- [x] **Step 4**: 검증 — top-level 11 (commit, fastapi-mvp, flutter-mvp, frontend-design, haeda-domain-context, local, resolve-conflict, set, skill-creator, smoke-test, using-skills), ARCHIVE/ 19
- [x] **Step 5**: 커밋 `chore(claude): feature-flow 스킬 + superpowers 중복 스킬 archive`

→ commit `469e89e`

---

## Task 1C: rules ARCHIVE 이동

**Files:** Move `.claude/rules/*.md` 15 개 → `.claude/rules/ARCHIVE/`

대상: agents.md, workflow.md, model-policy.md, tdd.md, verification.md, worktree-parallel.md, planner-worktree.md, design-worktree.md, claude-config-sync.md, autonomous-execution.md, regression-prevention.md, worktree-task-report.md, automation.md, app-guard.md, server-guard.md.

- [ ] **Step 1**: `mkdir -p .claude/rules/ARCHIVE`
- [ ] **Step 2**: 일괄 git mv 15 → ARCHIVE/
- [ ] **Step 3**: 검증 — top-level 4 (coding-style, docs-protection, git-workflow, security), ARCHIVE/ 15
- [ ] **Step 4**: 커밋 `chore(claude): feature-flow / 워크트리 role 룰 archive`

---

## Task 2: 유지 파일의 stale 참조 cleanup

**Files (Modify):**
- `.claude/rules/git-workflow.md`
- `.claude/skills/resolve-conflict/SKILL.md`
- `.claude/skills/fastapi-mvp/SKILL.md`
- `.claude/skills/flutter-mvp/SKILL.md`
- `.claude/skills/skill-creator/SKILL.md`
- `.claude/skills/using-skills/SKILL.md`

archived 항목 (worktree-parallel, agents, workflow, feature-flow, backend-builder, flutter-builder, qa-reviewer 등) 참조를 superpowers 또는 새 정책으로 교체하거나 삭제.

상세 변경 내역은 controller 가 implementer subagent 에게 inline 으로 전달.

- [ ] **Step 1**: 6 파일 갱신
- [ ] **Step 2**: 잔존 stale 참조 grep 검증 — 출력 없음
- [ ] **Step 3**: 커밋 `chore(claude): 유지 파일에서 archived 룰/에이전트 참조 정리`

---

## Task 3: 신규 rule 4 개 작성

**Files (Create):**
- `.claude/rules/language-policy.md`
- `.claude/rules/local-build-verification.md`
- `.claude/rules/ios-simulator.md`
- `.claude/rules/superpowers-default.md`

각 파일의 본문은 controller 가 implementer subagent 에게 inline 으로 전달.

- [ ] **Step 1**: 4 파일 작성
- [ ] **Step 2**: 검증 — 4 파일 stat, 각 30-100 줄
- [ ] **Step 3**: 커밋 `feat(claude): superpowers 기본화 신규 룰 4 개 추가`

---

## Task 4: 신규 로컬 스킬 2 개 작성

**Files (Create):**
- `.claude/skills/haeda-build-verify/SKILL.md`
- `.claude/skills/haeda-ios-deploy/SKILL.md`

각 파일의 본문은 controller 가 implementer subagent 에게 inline 으로 전달.

- [ ] **Step 1**: 디렉토리 + 파일 작성
- [ ] **Step 2**: 검증 — frontmatter description 길이 ≥ 30 자
- [ ] **Step 3**: 커밋 `feat(claude): haeda-build-verify / haeda-ios-deploy 로컬 스킬 추가`

---

## Task 5: CLAUDE.md 갱신

**Files (Modify):** `CLAUDE.md` (43 줄 → 약 80 줄로 전체 교체)

새 본문은 controller 가 implementer subagent 에게 inline 으로 전달.

- [ ] **Step 1**: 전체 교체
- [ ] **Step 2**: 검증 — 60-100 줄, 헤딩에 Workflow / Source of Truth / MVP Guardrails / Rules / Local Skills / Out of Scope / Rollback 포함
- [ ] **Step 3**: 커밋 `feat(claude): CLAUDE.md 를 superpowers 기본 색인으로 재작성`

---

## Task 6: settings.json 커밋

**Files (Modify):** `.claude/settings.json`

`enabledPlugins.superpowers@claude-plugins-official: true` 가 추가된 상태를 커밋.

- [ ] **Step 1**: JSON 유효성 + superpowers 활성화 확인
- [ ] **Step 2**: 커밋 `feat(claude): superpowers 플러그인 활성화`

---

## Task 7: smoke test + 작업 보고서

**Files (Create):** `docs/reports/2026-04-25-claude-superpowers-default.md`

정적 검증 후 보고서 작성.

- [ ] **Step 1**: top-level 디렉토리 카운트 (agents=0, rules=8, skills=13)
- [ ] **Step 2**: 신규 파일 stat (4 rules + 2 skills + 1 spec + 1 plan + 1 report = 9)
- [ ] **Step 3**: stale 참조 grep 검증
- [ ] **Step 4**: settings.json superpowers 활성 검증
- [ ] **Step 5**: 보고서 작성 (Request / Context / Decisions / Actions / Verification / Follow-ups / Related 7 섹션)
- [ ] **Step 6**: 커밋 `docs(claude): superpowers 기본화 작업 보고서`

---

## Task 8: force-with-lease push + PR

**Action:** worktree-claude 브랜치를 origin 에 force-with-lease push, PR 생성, 자동 머지.

- [ ] **Step 1**: 로컬 상태 확인 — HEAD 9 신규 커밋, origin/main 4 커밋 뒤
- [ ] **Step 2**: `git push origin worktree-claude --force-with-lease`
- [ ] **Step 3**: `gh pr create` (제목 한국어, 본문 한국어)
- [ ] **Step 4**: `gh pr merge --merge`
- [ ] **Step 5**: 로컬 sync (`git fetch origin main && git rebase origin/main`)
- [ ] **Step 6**: 사용자에게 PR 번호 + 머지 SHA + 다른 워크트리 재시작 안내

---

## Self-Review Notes

### Spec coverage

| Spec 섹션 | Plan 태스크 |
|----------|-----------|
| §3.1 ARCHIVE 이동 | Task 1A / 1B / 1C |
| §3.2 유지 파일 (참조 cleanup 필요) | Task 2 |
| §3.3 신규 rule 4 개 | Task 3 |
| §3.3 신규 로컬 스킬 2 개 | Task 4 |
| §3.4 CLAUDE.md | Task 5 |
| §3.4 settings.json | Task 6 |
| §6 step 7 smoke test | Task 7 |
| §6.1 force-with-lease | Task 8 |

### 사고 기록

Task 1B 구현 중 haiku implementer 가 task 외 파일 (untracked spec/plan, unstaged settings.json) 을 임의 reset/delete. archival 결과는 정확. controller 가 spec/plan/settings.json 재생성 후 task 진행. 이후 implementer prompt 에 scope rule 강조.
