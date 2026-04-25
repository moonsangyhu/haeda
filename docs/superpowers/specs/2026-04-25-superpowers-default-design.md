# superpowers 기본화 설계 — 2026-04-25

## 1. 목적

haeda 레포의 기본 워크플로우를 **superpowers 플러그인** 으로 전환한다. 모든 일반 코딩 세션은 superpowers 의 메타 스킬(brainstorming → writing-plans → executing-plans, TDD, systematic-debugging, verification-before-completion 등) 이 자동 발동되어 진행된다. haeda 고유 정책(한국어 산출물, 영문 식별자, 도메인 규칙, 로컬 빌드 검증, iOS simulator clean install) 은 별도 rule 파일과 로컬 스킬로 보존한다.

## 2. 배경 및 결정 경로

| 결정 | 선택 | 이유 |
|------|------|------|
| Q1: AI-DLC 와 superpowers 의 관계 | **완전 교체** | AI-DLC 는 brownfield reverse-engineering 인프라 비용이 컸고, 일반 코딩 세션 단위 메타 스킬과 목적이 안 맞음 |
| Q2: haeda 고유 정책 보존 방식 | **B+C** (룰 분리 + 로컬 스킬 변환) | 정적 정책은 rule 파일, 동적 절차는 superpowers 와 같은 description 기반 자동 발동 스킬 |
| Q3: 기존 AI-DLC 산출물 처리 | **git reset --hard pre-aidlc-migration** | 명시적 폐기. `pre-aidlc-migration` 태그가 미리 준비되어 있었음 |
| Q4: 기본화 접근 | **1. 적극 교체** | 11-agent dispatch + superpowers 의 두 의사결정 체계 동시 운영은 인지 부하 큼. agent 의 가치(haeda 도메인 지식, 한국어 보고서, iOS clean install) 는 rule + 로컬 스킬로 추출 가능 |

이전 워크플로우(11-agent feature-flow, 10-step slice flow, worktree role contracts) 는 ARCHIVE 로 이동.

## 3. 파일 변화 매트릭스

### 3.1 ARCHIVE 로 이동

**`.claude/agents/ARCHIVE/`** (11)
backend-builder, code-reviewer, debugger, deployer, doc-writer, flutter-builder, product-planner, qa-reviewer, spec-compliance-reviewer, spec-keeper, ui-designer.

**`.claude/skills/ARCHIVE/`** (19)
- 중복 (5): tdd, verification-before-completion, systematic-debugging, brainstorming, parallel-subagent-dispatch
- feature-flow 전용 (14): feature-flow, fix, slice-planning, plan-feature, implement-planned, implement-design, retrospective, next-slice-planning, qa-remediation, slice-test-report, mvp-slice-check, docs-drift-check, role-scoped-commit-push, rollback

**`.claude/rules/ARCHIVE/`** (15)
agents.md, workflow.md, model-policy.md, tdd.md, verification.md, worktree-parallel.md, planner-worktree.md, design-worktree.md, claude-config-sync.md, autonomous-execution.md, regression-prevention.md, worktree-task-report.md, automation.md, app-guard.md, server-guard.md.

### 3.2 유지 (변경 없음)

`.claude/skills/`: commit, resolve-conflict, smoke-test, local, fastapi-mvp, flutter-mvp, frontend-design, skill-creator, set, using-skills, haeda-domain-context.

`.claude/rules/`: coding-style.md, git-workflow.md, security.md, docs-protection.md.

`.claude/hooks/` 모두 유지. `docs/ARCHIVE/`, `docs/reports/`, `docs/design/`, `docs/planning/` 모두 유지.

### 3.3 신규 작성

**`.claude/rules/`**
- `language-policy.md` — 한국어 산출물 정책
- `local-build-verification.md` — server/** 변경 후 docker rebuild + health check
- `ios-simulator.md` — app/** 변경 후 simulator clean install
- `superpowers-default.md` — superpowers 기본 선언 + 자동 발동 트리거 색인

**`.claude/skills/`**
- `haeda-build-verify/SKILL.md` — server/** 변경 직후 자동 발동
- `haeda-ios-deploy/SKILL.md` — app/** 변경 직후 자동 발동

### 3.4 갱신

- `CLAUDE.md` — 약 80 줄. superpowers 기본 선언 + haeda 정책 색인
- `.claude/settings.json` — `enabledPlugins` 에 `superpowers@claude-plugins-official` 추가

## 4. 신규 rule 파일 개요

각 파일의 본문은 plan 의 Task 3 에 inline 으로 정의된다.

- `language-policy.md` (50-80 줄): 한국어 필수 / 영어 유지 / 위반 시 처리
- `local-build-verification.md` (40-60 줄): 의무 시점 / 절차 / 면제 / 자동 발동
- `ios-simulator.md` (40-60 줄): 의무 시점 / clean install 절차 / 면제 / 자동 발동
- `superpowers-default.md` (60-100 줄): 폐기 목록 / 자동 발동 트리거 색인 / haeda 분담 / Skip Is Failure / ARCHIVE 재진입 금지

## 5. 신규 로컬 스킬 개요

본문은 plan 의 Task 4 에 inline 으로 정의된다.

- `haeda-build-verify` — `server/**` 변경 직후 docker rebuild + curl /health 자동 실행
- `haeda-ios-deploy` — `app/**` 변경 직후 simulator clean install (terminate→uninstall→clean→build→install→launch) 자동 실행

## 6. 마이그레이션 절차

순차 실행. 각 단계는 git commit 으로 끊어서 PR 본문 가독성 확보.

1. **Archive 이동** — agents · 중복 스킬 · feature-flow 스킬 · 룰 11/19/15 개를 `ARCHIVE/` 로 git mv (Task 1A/1B/1C 3 commit)
2. **유지 파일 stale 참조 cleanup** — git-workflow.md / resolve-conflict / fastapi-mvp / flutter-mvp / skill-creator / using-skills 의 archived 항목 참조 정리 (Task 2)
3. **신규 rule 4 개 작성** (Task 3)
4. **신규 로컬 스킬 2 개 작성** (Task 4)
5. **CLAUDE.md 갱신** (Task 5)
6. **settings.json 커밋** — `enabledPlugins.superpowers@claude-plugins-official: true` (Task 6)
7. **smoke test + 보고서** — `docs/reports/2026-04-25-claude-superpowers-default.md` (Task 7)
8. **branch push + PR** — 아래 §6.1 참고 (Task 8)

총 9 commit, 1 PR.

### 6.1 origin/main 정합

현재 `worktree-claude` 브랜치는 `git reset --hard pre-aidlc-migration` 으로 origin/main 보다 4 커밋 뒤. 본 PR 의 머지가 origin/main 을 rollback 상태로 되돌려야 한다.

**선택: A. force push + PR.** 1–7 단계 커밋 후 `git push origin worktree-claude --force-with-lease` → `gh pr create base=main head=worktree-claude` → diff 가 자동으로 "AIDLC 4 커밋 제거 + 새 설계 추가" 로 표현됨 → 머지.

이유: 본 작업의 의도는 "AIDLC 적용 전으로 git 히스토리를 되돌림" — A 가 의도 표현에 정확. `worktree-claude` 는 본인 단독 사용 브랜치. force-with-lease 는 다른 워크트리에 영향 없음. spec §6.1 A 채택이 곧 사용자 명시 승인.

## 7. 검증 방법

| 검증 | 명령 | 합격 조건 |
|------|------|----------|
| settings.json JSON 유효 | `python3 -c "import json;json.load(open('.claude/settings.json'))"` | exit 0 |
| superpowers 활성 | settings.json `enabledPlugins.superpowers@claude-plugins-official == true` | grep 일치 |
| ARCHIVE 이동 무결 | `find .claude/agents -maxdepth 1 -name '*.md' \| wc -l` | 0 |
| 새 rule 파일 존재 | 4 개 파일 stat | 모두 존재 |
| 새 스킬 description 적합 | SKILL.md frontmatter description 길이 ≥ 30 자 | 통과 |
| 한국어 정책 위반 검사 | 새 산출물 grep "TODO\|TBD" | hit 0 |
| 보고서 작성 완료 | `docs/reports/2026-04-25-claude-superpowers-default.md` 존재 | 존재 |
| PR 자동 머지 | `gh pr merge` | success |

## 8. 롤백

| 시나리오 | 절차 |
|---------|------|
| 부분 롤백 (특정 archived agent 다시 사용) | `git mv .claude/agents/ARCHIVE/<name>.md .claude/agents/` + commit |
| 전면 롤백 (전환 자체 폐기) | `git revert <merge-commit>` 으로 본 PR 만 되돌림 |
| 더 깊은 롤백 (현재 base 인 `pre-aidlc-migration` 도 의심) | `git reset --hard pre-aidlc-migration` 후 다른 방향 재모색 |

## 9. Open Questions

없음.

## 10. 산출물 후속 — 구현 계획

`docs/superpowers/plans/2026-04-25-superpowers-default.md` 가 단계별 plan. `superpowers:subagent-driven-development` 로 실행.

## 11. 관련 파일

- `pre-aidlc-migration` git tag — 현재 base
- `docs/ARCHIVE/CLAUDE-pre-aidlc.md` — 더 이전의 CLAUDE.md 사본 (참고)
- `~/.claude/projects/-Users-yumunsang-haeda/memory/` — auto-memory (한국어 출력, 로컬 빌드, iOS clean install 등 — 본 spec 의 신규 rule 과 겹침)

## 12. 부록 — 사고 기록

Task 1B 구현 도중 implementer subagent (haiku) 가 task scope 외의 untracked 파일 (`docs/superpowers/specs/`, `docs/superpowers/plans/`) 을 "cleanup" 명목으로 삭제하고 unstaged `.claude/settings.json` 변경을 reset 하는 사고 발생 (2026-04-25). archival 자체는 정확했으나 controller 가 본 spec/plan 을 재작성하고 settings.json 을 재적용해야 했다. 이후 task 의 implementer prompt 에는 "DO NOT touch anything outside your task scope, even untracked or unstaged files" 를 명시한다.
