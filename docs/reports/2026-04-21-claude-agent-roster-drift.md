# spec-compliance-reviewer roster drift 진단 및 규칙 보강

> **ROSTER REFRESH REQUIRED**: 본 보고서는 신규 에이전트 추가가 아니라 기존 roster 누락 진단이므로 재시작은 **stale 워크트리 한정**으로 필요함 (하단 Follow-ups 참고).

- Date: 2026-04-21
- Worktree (수행): `.claude/worktrees/claude` (branch: `worktree-claude`)
- Worktree (영향): `worktree-debug`, `worktree-planner` — 두 브랜치 rebase 필요
- Role: claude

## Request

> spec-compliance-reviewer 에이전트가 available agents 에 없어 code-reviewer 결합 수행. workflow.md 정의와 agents.md 간 mismatch 보완 필요 (→ claude role 워크트리 후속 과제).

## Referenced Reports (Read-before-Write)

- `docs/reports/2026-04-11-claude-rules-task-report-and-config-sync.md` — `claude-config-sync.md` rule 의 도입 배경. 본 수정은 이 rule 에 **신규 에이전트 전파** 조항 하나만 추가해 기존 구조를 훼손하지 않음.
- `docs/reports/2026-04-20-claude-regression-prevention-rule.md` — "멀쩡한 걸 수정하지 말 것" 원칙. 본 보고서 작성 시 `workflow.md` / `agents.md` 를 재확인한 결과 이미 일관됨 → 수정하지 않고 규칙 보강만 수행.
- `docs/reports/2026-04-20-claude-guard-reports-exception.md` — 바로 앞 작업. 같은 "hook / rule 표 간 누락 예외 발견 → 최소 수정" 패턴 참고.

검색 키워드: `spec-compliance-reviewer`, `agent roster`, `claude-config-sync`, `worktree-debug`, `worktree-planner`

## Root cause / Context

사용자 보고를 "workflow.md ↔ agents.md 문서 mismatch" 로 가정하고 조사를 시작했으나 원인은 다른 곳에 있었다.

### 관측

```bash
$ for b in worktree-feature worktree-design worktree-debug worktree-planner worktree-claude; do
    f=$(git ls-tree -r $b -- .claude/agents/spec-compliance-reviewer.md)
    [ -n "$f" ] && echo "$b: PRESENT" || echo "$b: MISSING"
  done
worktree-feature: PRESENT
worktree-design:  PRESENT
worktree-debug:   MISSING
worktree-planner: MISSING
worktree-claude:  PRESENT

$ git log --all --oneline -- .claude/agents/spec-compliance-reviewer.md
941a47d feat(claude): superpowers 기반 agent/skill 재정비

$ for b in worktree-debug worktree-planner; do
    git merge-base --is-ancestor 941a47d $b && echo "$b OK" || echo "$b MISSING 941a47d"
  done
worktree-debug:   MISSING 941a47d
worktree-planner: MISSING 941a47d
```

### 해석

- `spec-compliance-reviewer.md` 는 `941a47d` 커밋에서 도입됨 (2026-04-19).
- `worktree-debug` 와 `worktree-planner` 두 브랜치는 이 커밋을 포함하지 않은 **stale** 상태.
- Claude Code 는 세션 시작 시점의 `.claude/agents/` 파일 시스템을 스캔해 available subagent_type 목록을 고정한다. 따라서 이 두 워크트리의 세션에서는 `spec-compliance-reviewer` 가 Agent 툴 호출 시 목록에 존재하지 않았고, 사용자는 우회로 `code-reviewer` 에 역할을 결합해 실행.
- `workflow.md` / `agents.md` 는 `spec-compliance-reviewer` 를 Step 4 post-implementation gate 로 정확히 정의하고 있어 문서 간 mismatch 없음. mismatch 는 **문서 ↔ stale 워크트리 파일 시스템** 사이에서 발생.

### 근본 원인

`claude-config-sync.md` 가 rule / hook / settings 파일의 전파는 강하게 규정하나, **신규 에이전트 파일 추가** 에 대한 별도 조항이 없다. rule/hook 은 rebase 후 즉시 효과를 내지만, 에이전트는 세션 시작 시점에만 로드되어 기존 세션에 자동 반영이 안 된다. 이 차이가 규칙에 반영되지 않아 사용자가 워크트리를 rebase 해도 새 에이전트가 목록에 나타나지 않는 착시가 발생할 수 있다.

## Actions

### 수정한 파일

- `.claude/rules/claude-config-sync.md`
  - §4-bis "Agent Roster Drift (신규 에이전트 추가 시)" 섹션 신설. 핵심 조항 4개:
    1. claude role 변경 보고서 최상단 `ROSTER REFRESH REQUIRED` 배너 의무
    2. Follow-ups 섹션에 워크트리별 재시작 절차 기재
    3. PR 제목에 `[roster]` 태그
    4. 에이전트 참조 문서 업데이트를 같은 PR 에서 수행
  - "주기적 검증" 하단 블록 추가 — 다른 워크트리 브랜치의 roster 파일을 `git ls-tree` 로 대조하는 점검 커맨드
  - §5 강제력 표에 "roster 배너 누락 → Document 게이트 실패" 행 추가

### 건드리지 않은 파일

- `.claude/rules/workflow.md` — `spec-compliance-reviewer` 관련 기술은 정합성 유지. 수정 없음. (regression-prevention: "멀쩡한 걸 수정하지 말 것")
- `.claude/rules/agents.md` — 동일.
- `.claude/agents/spec-compliance-reviewer.md` — 파일은 정확히 존재. 수정 없음.
- `worktree-debug`, `worktree-planner` 브랜치 — claude role 이 다른 워크트리 브랜치를 force push 하지 않는다 (`git-workflow.md`). 각 워크트리 세션에서 사용자가 rebase 후 세션 재시작 필요.

## Verification

- **Static grep**:
  ```bash
  rg "Agent Roster Drift|ROSTER REFRESH REQUIRED" .claude/rules/claude-config-sync.md
  ```
  → 두 키워드 모두 hit. PASS.

- **규칙 무결성 재확인**:
  ```bash
  rg "spec-compliance-reviewer" .claude/rules/workflow.md .claude/rules/agents.md | wc -l
  ```
  → `workflow.md`, `agents.md` 모두에서 여러 라인 hit. 문서 정의는 이미 정합성을 갖추고 있음을 재확인.

- **파일 시스템**: 본 워크트리(`worktree-claude`) 의 `.claude/agents/spec-compliance-reviewer.md` 존재 확인. PASS.

## Follow-ups

사용자 조치 (본 커밋만으로는 해소되지 않음):

1. **worktree-debug** 를 rebase 하고 세션 재시작:
   ```bash
   cd .claude/worktrees/debug  # 또는 해당 워크트리 경로
   git fetch origin main
   git rebase origin/main
   # 현재 세션 종료 후 새 `claude` 세션 시작
   ```
2. **worktree-planner** 를 rebase 하고 세션 재시작:
   ```bash
   cd .claude/worktrees/planner
   git fetch origin main
   git rebase origin/main
   # 현재 세션 종료 후 새 `claude` 세션 시작
   ```
3. 재시작 후 각 워크트리에서 Agent 툴 호출 시 `subagent_type: spec-compliance-reviewer` 가 목록에 나타나는지 확인.

본 `.claude/rules/` 변경은 rule 텍스트이므로 기존 세션들도 다음 rebase 이후 참조 가능. 단 roster 자체는 세션 재시작 없이는 갱신되지 않음.

## Related

- `.claude/rules/claude-config-sync.md` §4-bis (본 수정의 대상)
- `.claude/agents/spec-compliance-reviewer.md` (누락됐던 에이전트)
- 선행 보고서: `docs/reports/2026-04-11-claude-rules-task-report-and-config-sync.md`
- 도입 커밋: `941a47d feat(claude): superpowers 기반 agent/skill 재정비`
