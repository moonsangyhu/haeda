# 2026-04-23 — AIDLC Workflow Migration

- **Date**: 2026-04-23
- **Worktree (수행)**: claude (`.claude/worktrees/claude`, branch `worktree-claude`)
- **Worktree (영향)**: all (CLAUDE.md, .claude/, docs/ source-of-truth)
- **Role**: claude

> **ROSTER REFRESH REQUIRED**: This migration archives all 11 agents and 21 skills and adds the AIDLC workflow as the new methodology. Every active Claude Code session in other worktrees MUST be restarted to pick up the new CLAUDE.md, agent roster, and skill list. Rebase alone is not enough.

## Request

사용자 요청 (2026-04-23):
> https://github.com/awslabs/aidlc-workflows#claude-code 를 우리 프로젝트에 도입하고 싶어. 기존에 여기 적용되어 있는 개발방법론이(feature-flow) 너무 주먹구구식이라 퀄리티가 잘 안나오는 것 같다는 판단이 들어서.

Plan mode 에서 4가지 결정을 사용자 승인받음:
1. **Approval gates**: AIDLC 원본대로 전면 승인 (autonomous-execution 무력화)
2. **Scope**: 전면 교체 (feature-flow / agents / worktree role 제거)
3. **기존 docs**: AIDLC brownfield reverse-engineering 으로 흡수
4. **Worktree**: 물리 구조만 유지, role 제약 제거

계획 파일: `~/.claude/plans/https-github-com-awslabs-aidlc-workflows-vast-flurry.md`

## Root cause / Context

기존 feature-flow (10-step skill + 11-agent + 6-worktree + 15-rule) 의 구조적 약점:
- **Pre-code design artifact 부재**: product-planner → 바로 code. 코드 작성 전 design 검토 단계 없음.
- **반응적 QA**: QA 가 step 6, code review 가 step 5 — 모두 코드 작성 이후.
- **실패 가시성 없음**: `docs/reports/` 11건 전부 성공 기록. 롤백·QA 실패·retry 탈진 사례 없음 → 품질 이슈가 구조적으로 드러나지 않음.
- **Worktree role 관리 오버헤드**: sentinel 파일, path guard, rebase-retry, deployer lockfile, config sync ritual 등 agent 가 이해·준수해야 할 메커니즘이 다수.

AIDLC 가 해결하는 지점:
- Inception 단계에서 requirements / user-stories / workflow-planning / application-design / units-generation **코드 이전** 문서화
- Construction per-unit 에서 functional-design / NFR / infrastructure-design → code-generation 순차 실행
- 각 stage 마다 사용자 explicit approval (품질 게이트 내장)
- `aidlc-docs/audit.md` 에 모든 user raw input + AI response + timestamp 기록 (결정 traceability)
- adaptive depth (minimal / standard / comprehensive) — hardcoded retry 대신 스코프 기반 조정

## Actions

계획된 10 phase 중 이 세션에서 수행한 것은 Phase 0–8 (Phase 6 reverse-engineering, Phase 7 first-feature dry-run 은 새 Claude Code 세션에서 사용자 주도로 수행 필요).

### Phase 0 — Safety net
- `git tag pre-aidlc-migration` 태그 생성 (전체 rollback 지점)
- `.deployer.lock` 존재 확인 → 없음 (skip)

### Phase 1 — Upstream AIDLC rules mirror
- `awslabs/aidlc-workflows@5c33ae7` (2026-04-23 fetch) 의 tarball 을 `.aidlc-rule-details/` 로 복사
- `.aidlc-rule-details/aidlc-rules-version.txt` 에 SHA 기록
- 31 files copied: common/, inception/, construction/, operations/, extensions/security/baseline/, extensions/testing/property-based/ + core-workflow.md

### Phase 2 — CLAUDE.md 재작성
- 기존 43 lines → 619 lines (AIDLC core-workflow verbatim + Haeda 프로젝트 addendum)
- 백업: `docs/ARCHIVE/CLAUDE-pre-aidlc.md`
- 새 구조: priority / adaptive principle / rule-details loading / extensions loading / content validation / question format / welcome message / Inception phase / Construction phase / Operations placeholder / key principles / audit log / directory structure / **Haeda addendum** (stack, code paths, always-enforced extensions, deprecated infra, retained utilities, worktrees, git, rollback)

### Phase 3 — Haeda always-enforced extensions (4)
모두 `*.opt-in.md` 없이 always-enforced 로 배치:

- `.aidlc-rule-details/extensions/haeda-tdd/haeda-tdd.md` — RED/GREEN/REFACTOR 강제, pytest/flutter test 실제 출력 인용 (5 rules)
- `.aidlc-rule-details/extensions/haeda-local-build/haeda-local-build.md` — `docker compose up --build -d backend` + `curl /health` + alembic 검증 (5 rules)
- `.aidlc-rule-details/extensions/haeda-flutter-ios-sim/haeda-flutter-ios-sim.md` — `flutter build ios --simulator` + terminate/uninstall/install/launch + screenshot (5 rules)
- `.aidlc-rule-details/extensions/haeda-domain-context/haeda-domain-context.md` — 터미놀로지 (English in code / Korean in UX), API envelope, error-code registry, season icons, size guardrails, MVP scope (6 rules)

### Phase 4 — feature-flow 인프라 archive (git mv, history 보존)
- `.claude/agents/ARCHIVE/` — 11 agent (product-planner, spec-keeper, backend-builder, flutter-builder, ui-designer, spec-compliance-reviewer, code-reviewer, qa-reviewer, debugger, deployer, doc-writer)
- `.claude/skills/ARCHIVE/` — 21 skill (feature-flow, plan-feature, slice-planning, implement-planned, implement-design, fix, brainstorming, next-slice-planning, qa-remediation, retrospective, slice-test-report, docs-drift-check, systematic-debugging, tdd, verification-before-completion, rollback, role-scoped-commit-push, mvp-slice-check, haeda-domain-context, fastapi-mvp, flutter-mvp)
- `.claude/rules/ARCHIVE/` — 13 rule (agents, automation, autonomous-execution, claude-config-sync, design-worktree, model-policy, planner-worktree, regression-prevention, tdd, verification, workflow, worktree-parallel, worktree-task-report)

**유지된 skill** (9): commit, frontend-design, local, parallel-subagent-dispatch, resolve-conflict, set, skill-creator, smoke-test, using-skills
**유지된 rule** (6): app-guard, coding-style, docs-protection, git-workflow, security, server-guard

### Phase 5 — Hook 조정
- `.claude/hooks/docs-guard.sh` 재작성: `docs/ARCHIVE/**` 를 read-only 로 블록 (나머지 경로는 통과)
- `.claude/hooks/push-gate.py` 재작성: legacy feature-flow QA report 체크 제거 → `aidlc-docs/audit.md` 에서 approval marker 탐색하는 gate 로 변경. 직접 main push 는 여전히 hard block.
- `.claude/hooks/planner-guard.sh`, `design-guard.sh`, `design-status-guard.sh` → `.disabled` 로 rename (role-path 제약 제거)
- `.claude/settings.json` 내 hook 참조 업데이트 — **permission 차단으로 사용자 approval 대기**. 현재는 disabled hook 이라 기능상 영향 없음. 사용자 수동 편집 또는 별도 승인 필요.

### Phase 6 prep — docs/ source-of-truth archive
다음 4개 파일을 `docs/ARCHIVE/` 로 이동 (git mv, history 보존):
- `docs/prd.md` → `docs/ARCHIVE/prd.md`
- `docs/user-flows.md` → `docs/ARCHIVE/user-flows.md`
- `docs/domain-model.md` → `docs/ARCHIVE/domain-model.md`
- `docs/api-contract.md` → `docs/ARCHIVE/api-contract.md`

유지된 docs (secondary 참조용): architecture.md, character-system-spec.md, decisions/, design/, local-dev.md, mvp-slice-01.md, planning/, raw-requirements.md, reports/, worktree-runbook.md. 이들은 AIDLC reverse-engineering 이 흡수할 입력.

### Phase 8 — 이 보고서 + PR commit (현재 단계)
- 보고서: `docs/reports/2026-04-23-claude-aidlc-migration.md` (본 파일)
- Commit + PR: 다음 단계

## Verification

### Migration 자체

```bash
$ git tag --list pre-aidlc-migration
pre-aidlc-migration

$ wc -l CLAUDE.md
619 CLAUDE.md

$ ls .aidlc-rule-details/
common  construction  extensions  inception  operations  core-workflow.md  aidlc-rules-version.txt

$ ls .aidlc-rule-details/extensions/
haeda-domain-context  haeda-flutter-ios-sim  haeda-local-build  haeda-tdd  security  testing

$ ls .claude/agents/ | grep -v ARCHIVE
(empty)

$ ls docs/ARCHIVE/
CLAUDE-pre-aidlc.md  api-contract.md  domain-model.md  prd.md  user-flows.md

$ git status --short | wc -l
57
```

### 의도된 결과

- AIDLC core-workflow 가 CLAUDE.md 에 embed 되어 있음 ✅
- 4 Haeda extensions always-enforced 로 배치 ✅
- 기존 agent/skill/rule 전부 ARCHIVE/ 로 이동 (git history 보존) ✅
- docs/ source-of-truth 4종 ARCHIVE/ 로 이동 ✅
- docs-guard.sh 가 docs/ARCHIVE/** 를 read-only 로 보호 ✅
- push-gate.py 가 audit.md approval 을 체크하도록 업데이트 ✅

### 검증 불가 (부분)

| 항목 | 상태 | 비고 |
|------|------|------|
| AIDLC workflow 실제 동작 | UNVERIFIED | Phase 6 (brownfield reverse-engineering) 을 새 세션에서 사용자 주도로 실행해야 함 |
| 4 haeda extensions 실제 enforce | UNVERIFIED | Phase 7 (첫 실전 feature) 에서 확인 |
| `.claude/settings.json` hook 배선 | BLOCKED | self-modification 차단. 사용자 approval 필요. 단 `.disabled` rename 으로 실질 영향 없음 |

## Follow-ups

### 즉시 (이 PR merge 직후)

1. **Settings.json 업데이트**: 사용자가 다음 수동 변경 필요 — `.claude/settings.json` 의 `PreToolUse.Write|Edit|NotebookEdit` hooks 중 `planner-guard.sh`, `design-guard.sh`, `design-status-guard.sh` 제거, `Bash` matcher PreToolUse 에 `push-gate.py` 추가. (plan file 파일에 전체 diff 있음)
2. **Worktree sentinel 삭제**: 다른 워크트리(`planner`, `design`)에 `.planner-worktree` / `.design-worktree` sentinel 파일이 있으면 삭제. 이 워크트리(claude)에는 없음.
3. **다른 워크트리 재시작**: claude / feature / design / planner / debug 모든 활성 Claude Code 세션을 Ctrl+D → 재기동.

### 단기 (다음 세션)

4. **Phase 6 — Brownfield reverse-engineering**: 새 세션에서 `Using AI-DLC, perform brownfield reverse engineering on the existing Haeda codebase. Treat docs/ARCHIVE/prd.md, docs/ARCHIVE/user-flows.md, docs/ARCHIVE/domain-model.md, docs/ARCHIVE/api-contract.md as authoritative input for the baseline.` 실행. 산출물: `aidlc-docs/inception/reverse-engineering/` + `aidlc-docs/inception/requirements/`. 사용자가 결과 approval.
5. **Phase 7 — First feature dry-run**: P1 backlog 에서 작은 feature 하나 픽업하여 `Using AI-DLC, implement <feature>` 로 전체 파이프라인 검증. 마찰점을 haeda extension 에 반영.

### 중기 (운영하며 튜닝)

6. **Extension 추가 검토**: 관찰된 마찰점에 따라 `haeda-coding-style/` (file/function size), `haeda-session-restart-warning/` 등 추가 가능.
7. **Minimal depth default**: 매 stage approval 이 속도 저하 크면, AIDLC 의 adaptive depth 에서 minimal 을 default 로 당기는 addendum.
8. **Memory cleanup**: `~/.claude/projects/.../memory/` 의 `feedback_*` 중 feature-flow 전제 엔트리 정리. 구체적으로 `feedback_build_verification.md`, `feedback_model_policy.md` 등은 outdated 가능.
9. **`using-skills` skill 업데이트**: 현재 archived skill 을 참조하는 부분 제거.

### 의도적 유예

- `impl-log/` freeze 여부 — plan 의 Open Items #2. 현재는 그대로 두고 Phase 7 운영 후 결정.
- `docs/decisions/` 이동 — plan 의 Open Items #1. 현재 위치 유지.

## Related

- **Plan file**: `~/.claude/plans/https-github-com-awslabs-aidlc-workflows-vast-flurry.md`
- **Upstream**: https://github.com/awslabs/aidlc-workflows/tree/5c33ae7
- **Rollback tag**: `pre-aidlc-migration` (pre-migration snapshot)
- **Archived legacy CLAUDE.md**: `docs/ARCHIVE/CLAUDE-pre-aidlc.md`
- **AIDLC Working Guide**: `.aidlc-rule-details/` (특히 `common/process-overview.md`, `common/session-continuity.md`)
