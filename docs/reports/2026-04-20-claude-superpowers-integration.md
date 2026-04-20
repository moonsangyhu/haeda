# Superpowers 기반 `.claude/` 재정비

- Date: 2026-04-20
- Worktree (수행): `.claude/worktrees/claude` (branch `worktree-claude`)
- Worktree (영향): 모든 worktree (rule/agent/skill 변경은 전체에 전파)
- Role: claude

## Request

> https://github.com/obra/superpowers 는 가장 유명한 claude agent 셋팅 플러그인 중 하나야. 아마 내 추측에는 이 haeda 프로젝트에서 쓰고있는 agent 와 skill 들과 같은 역할을 하는 것들이 아주 고도화된 형태로 구현되어 있을거야. 왜냐하면 지금까지 나는 필요할때마다 주먹구구식으로 만들어 달라고 했거든. 이제 재정비 한 번 할때가 온 것 같아. 내 요구사항은 간단해. 이걸 너가 할수 있는 한 아주 깊이 분석해서, 이미 같은 기능을 하는 agent, skill 등은 보강해주고 우리 프로젝트에 필요하다 싶은 건 도입해줘. 도입 후에는 내가 뭐 셋팅할 필요 없이 바로 사용할 수 있어야 해.

## Root cause / Context

haeda 프로젝트는 사용자가 필요할 때마다 즉흥적으로 추가한 10-agent / 23-skill 구성을 갖고 있었다. 워크트리 병렬화와 role contract 등은 정교한 반면, **"어떤 때 어떤 스킬이 호출되어야 하는지" 의 강제 메커니즘이 부재**했고, superpowers 가 갖춘 몇 가지 핵심 품질 장치(TDD 강제, 체계적 디버깅 프로토콜, 증거 기반 완료 선언, 2단계 코드 리뷰, brainstorming 단계, retrospective) 가 구조화되어 있지 않았다.

본 작업은 사용자가 "설정 없이 바로 사용 가능해야" 한다는 요구에 맞춰 파일 기반으로 완결된 형태로 통합했다.

## Actions

### 신규 파일 (10개)

Skills (`.claude/skills/<name>/SKILL.md`):
- `tdd/SKILL.md` — RED-GREEN-REFACTOR 루프 강제, builder completion output 템플릿
- `systematic-debugging/SKILL.md` — 4단계 근본 원인 조사 (재현 → 계층 추적 → 원인 정리 → 수정 계획 → 실행 → 검증), Anti-pattern 목록
- `verification-before-completion/SKILL.md` — "완료" 주장 전 5단계 체크리스트, 금지 어휘, 에이전트별 의무 지점
- `brainstorming/SKILL.md` — 9단계 대화형 아이디어 shaping (plan-feature 전처리)
- `retrospective/SKILL.md` — docs/reports 말미에 What worked / What could improve / Process signal 3섹션 append
- `using-skills/SKILL.md` — 메타 스킬, "skill 이 적용되면 반드시 호출" 원칙, 주요 스킬 발동 트리거 인덱스
- `parallel-subagent-dispatch/SKILL.md` — 독립적 여러 작업의 subagent 병렬 발사 가이드

Agent (`.claude/agents/<name>.md`):
- `spec-compliance-reviewer.md` (model: sonnet) — **post-implementation** spec 준수 검토 (builder 후 / code-reviewer 전). `spec-keeper` (pre-implementation) 와 역할 분리

Rules (`.claude/rules/<name>.md`):
- `tdd.md` — TDD 의무화 레벨 (strong recommend + code-reviewer blocking gate)
- `verification.md` — 증거 기반 완료 선언 강제

### 수정 파일 (13개)

Agents — skill 참조 및 execution contract 추가:
- `code-reviewer.md` — §8 에 TDD 증거 체크 추가, Never Do 에 "spec compliance 판단 금지" 명시
- `debugger.md` — `systematic-debugging`, `tdd`, `verification-before-completion` 스킬 연결
- `product-planner.md` — Rough-Idea Gate 추가 (`brainstorming` 선호출)
- `backend-builder.md` — skills 에 `tdd`, `verification-before-completion` 추가, Phase 3 를 TDD 사이클로 재작성, completion output 에 `### TDD Cycle Evidence` + `### Verification` 섹션 추가
- `flutter-builder.md` — 동일 변경
- `qa-reviewer.md` — `verification-before-completion` 스킬 연결, verdict 출력 전 증거 인용 의무
- `doc-writer.md` — `retrospective` 스킬 연결, docs/reports 작성 시 3섹션 필수
- `deployer.md` — `verification-before-completion` 스킬 연결, 최종 보고 명령+출력 인용 의무

Rules:
- `agents.md` — 11-agent 표로 확장, dispatch chain 업데이트 (spec-compliance-reviewer 삽입), Gate Rules Summary 에 Spec Compliance 행 추가
- `workflow.md` — 9-step → **10-step** 확장, Step 4 Spec Compliance Review 신설, Verification Principles 에 `verification-before-completion` + tdd 참조 추가

Skills:
- `feature-flow/SKILL.md` — 10-step 재번호, Step 4 spec-compliance-reviewer 단계 신설, 모든 builder/reviewer 의 skill 참조 명시
- `fix/SKILL.md` — debugger/builder 가 `systematic-debugging` + `tdd` 스킬 준수 명시
- `plan-feature/SKILL.md` — Rough Idea Gate (brainstorming 선호출 권고)

CLAUDE.md — rule 인덱스에 `tdd.md`, `verification.md` 추가, agent 수 10 → 11, workflow 9-step → 10-step 반영

### 의도적으로 도입하지 않은 것

- `using-git-worktrees` (해다 워크트리 전략이 더 정교)
- `finishing-a-development-branch` (`/commit` + `/rollback` + `role-scoped-commit-push` 분산 구현)
- `writing-plans` (slice-planning / plan-feature 와 중복)
- `requesting-code-review` / `receiving-code-review` (dispatch chain 에 이미 자동 호출됨)
- `writing-skills` (`skill-creator` 있음)
- polyglot session-start hook (복잡성 증가 대비 효과 미미)
- 완전한 2-agent 리뷰 분리 (code-reviewer 는 품질 전용 유지, spec-compliance 만 분리)

## Verification

### 정적 검증

```
=== spec-compliance-reviewer model ===
---
name: spec-compliance-reviewer
...
model: sonnet
tools: Read Glob Grep Bash

=== 신규 skill frontmatter 체크 ===
OK: tdd
OK: systematic-debugging
OK: verification-before-completion
OK: brainstorming
OK: retrospective
OK: using-skills
OK: parallel-subagent-dispatch

=== 신규 rule 파일 존재 ===
-rw-r--r--@ 1 yumunsang  staff  3461  4월 20 21:13 .claude/rules/tdd.md
-rw-r--r--@ 1 yumunsang  staff  3045  4월 20 21:14 .claude/rules/verification.md

=== CLAUDE.md 내 새 rule 링크 ===
- **tdd.md** — 모든 production 코드 변경은 RED-GREEN-REFACTOR 사이클 (MANDATORY)
- **verification.md** — "완료/pass" 주장 전 증거 인용 필수 (MANDATORY)
```

### Plan policy 준수 확인

- `product-planner.md`: `model: opus` (기존 유지, brainstorming 스킬만 추가)
- `spec-compliance-reviewer.md`: `model: sonnet` (신규, review 분류 → Sonnet 배정)
- 기타 수정된 agent 모두 기존 모델 필드 유지

### 흐름 검증 (다음 feature 작업 시 자연스럽게 확인될 예정)

- [ ] 사용자가 러프 아이디어 제출 → `product-planner` 가 `brainstorming` 선호출하는지
- [ ] builder completion output 에 `### TDD Cycle Evidence` (RED + GREEN 인용) 포함되는지
- [ ] `code-reviewer` 다음 체인이 아니라 **그 앞**에 `spec-compliance-reviewer` 호출되는지
- [ ] `qa-reviewer` 최종 verdict 에 명령+출력 발췌 인용되는지
- [ ] `doc-writer` 가 쓴 `docs/reports/...` 말미에 Retrospective 3섹션 존재하는지

### 회귀 없음 확인

- `.claude/hooks/*` guard 들: 건드리지 않음, 기존대로 작동
- `.claude/settings.json`: 변경 없음, 새 permission/hook 불필요
- worktree-parallel.md / git-workflow.md / security.md: 수정 없음
- `/feature-flow`, `/fix`, `/commit`, `/rollback`: 스킬 내부 링크만 업데이트, 외부 인터페이스 동일

## Follow-ups

- **다른 워크트리의 기존 세션은 재시작 필요**: `.claude/` 변경은 세션 시작 시 로드되므로, 이미 실행 중인 front/backend/qa/feature 워크트리 세션은 다음 작업 시작 전 반드시 Claude Code 를 재시작하거나 최소한 `git fetch origin main && git rebase origin/main` 후 세션 재로드. (`.claude/rules/claude-config-sync.md` §4 규정)
- 다음 feature 작업 시 spec-compliance-reviewer 가 체인에 들어갔는지 **실제 호출 확인 필요**. feature-flow Step 4 에서 자동 호출되지만, 첫 실 사용 시 Main 의 호출 누락 여부를 체크.
- `using-skills` 의 발동 트리거 인덱스는 향후 스킬 추가 시 함께 갱신해야 함 (자동 아님).
- code-reviewer 의 TDD evidence blocking 이 너무 엄격해 빌더가 자주 reject 당하면 `.claude/rules/tdd.md` 의 강제력을 "strong recommend" → "warning only" 로 완화 고려.
- Process signal 섹션(`[ ]` 체크박스) 누적분은 `claude` role 에서 주기적으로 스윕해 실제 rule/agent/skill 변경으로 반영.

## Related

- Plan: `/Users/yumunsang/.claude/plans/https-github-com-obra-superpowers-sparkling-wilkinson.md`
- 외부 분석 대상: https://github.com/obra/superpowers
- 참조 rules: `agents.md`, `workflow.md`, `model-policy.md`, `claude-config-sync.md`
- 참조 skills: `feature-flow/SKILL.md`, `fix/SKILL.md`, `plan-feature/SKILL.md`

## Retrospective

### What worked (반복 재현할 패턴)
- 두 Explore 에이전트를 병렬 발사 (superpowers 외부 분석 + 현 `.claude/` 인벤토리) — 서로 독립적이어서 시간 절반으로 단축. `parallel-subagent-dispatch` 스킬이 이 패턴을 정식화했다.
- Plan mode 에서 상세 plan 파일 작성 → ExitPlanMode → 파일 단위 순차 작업. 중간에 context 소진 없이 완결.
- 신규 skill 작성 시 cross-skill reference 섹션을 모두 포함해 skill 간 연결을 명시 (`tdd` ↔ `systematic-debugging` ↔ `verification-before-completion` 삼각). 향후 유지보수 시 영향 범위 파악 용이.

### What could improve (다음에 반영)
- 하나의 Write 호출이 "internal error" 로 사일런트 실패해 3개 파일 저장이 누락된 일이 있었음 (시스템 에러). 대용량 파일 batch write 시 직후 `ls` 로 존재 확인하는 습관 필요.
- spec-compliance-reviewer 가 dispatch chain 에 들어갔지만, 기존 feature-flow 의 각 단계 "재작업 retry max N" 규칙을 새 gate 에 맞춰 세밀히 검토하지 못했음 — 실 사용 시 retry 경로가 복잡해질 수 있음.
- retrospective 섹션을 doc-writer 가 **매번 빠뜨리지 않도록** hook 으로 강제하는 방안을 검토하지 않았음. 현재는 Document gate 실패로만 잡음.

### Process signal (rule/agent/skill 추가·수정 후보)
- [ ] docs-guard.sh 나 신규 hook 으로 `docs/reports/**/*.md` 에 `## Retrospective` 섹션이 없으면 차단 (doc-writer 강제의 이중 안전망)
- [ ] code-reviewer 의 TDD evidence 체크에 정규식 강제 (`### TDD Cycle Evidence` + `### RED` + `### GREEN` 세 문구 모두 요구)
- [ ] 첫 실 사용 후 spec-compliance-reviewer 와 code-reviewer 의 역할 분리가 중복 체크를 유발하는지 관측, 필요 시 한쪽에서 체크리스트 재분배
- [ ] `using-skills` 인덱스를 agent 의 frontmatter `skills:` 필드와 자동 싱크 (수동 관리는 drift 발생 가능)
