# Task Report / Config Sync 룰 도입

- **Date**: 2026-04-11
- **Worktree (수행)**: `claude`
- **Worktree (영향)**: 모든 워크트리 (`backend`, `front`, `qa`, `debug`, `feature`, 그 외 생성 예정분 포함)
- **Role**: claude

## Request

사용자 요청 2건을 하나의 작업 단위로 묶어 처리:

1. "앞으로는 각 워크트리에서 작업 하나 마칠 때마다 무슨 워크트리에서 무슨 작업 했는지 보고 형식으로 문서 남겨줬으면 좋겠어. 깃에서 다 확인할 수 있게."
2. "방금 말한 각 워크트리에서 작업한거 문서로 만들어야 한다는 내용은 아예 rule 로 반강제로 agent 들이 시행하도록 해야 해."
3. "여기서 수정한 클로드 관련 규칙들은 다른 worktree 에서도 즉시 적용받을 수 있어야 해. 앞으로도 그렇게 되도록 rule 로 만들어줘."

## Context

기존 규칙 체계는 `.claude/rules/` 아래 여러 도메인 규칙으로 나뉘어 있고 `CLAUDE.md` 가 인덱스 역할을 했다. 그러나 (a) 워크트리별 작업 추적, (b) claude role 설정 변경의 즉시 전파에 대한 명시적 규칙이 없었다. 이번 변경은 두 축을 규칙으로 승격해 에이전트들이 "반강제"로 준수하도록 만드는 것이다.

기존 자산 중 활용한 것:
- `.claude/rules/worktree-parallel.md` — role contract, rebase-retry, shared-directory filename convention, startup ritual
- `.claude/rules/workflow.md` — 9-step slice flow, gate 정의
- `.claude/rules/agents.md` — 에이전트별 책임 분장
- `docs/reports/` 디렉토리 자체는 이미 존재, filename convention 도 이미 정의되어 있었음

## Actions

생성한 rule 파일 2건:

1. `.claude/rules/worktree-task-report.md` — 모든 상태 변경 작업에 `docs/reports/YYYY-MM-DD-{role}-{slug}.md` 를 생성·커밋하도록 강제. 필수 섹션 7개 정의(Header / Request / Root cause / Actions / Verification / Follow-ups / Related). 정식 파이프라인은 `doc-writer` 가, 직접 수정·config 변경은 Main 이 직접 작성. 보고서 없이 `/commit` 금지. feature-flow 의 Document (Step 7) 게이트와 동급으로 취급.

2. `.claude/rules/claude-config-sync.md` — (a) claude role 의 `.claude/**` / `CLAUDE.md` 수정은 **즉시** rebase-retry push, (b) 모든 non-claude role 은 **작업 시작 직전** `git fetch origin main && git rebase origin/main` 실행 의무, (c) 장기 세션은 작업 사이에 중간 sync 재실행, (d) 이미 실행 중인 다른 세션은 Claude Code 재시작해야 완전 반영되므로 claude 변경 보고서에 "다른 세션 재시작 필요" 경고를 follow-up 에 명시.

수정한 파일 3건:

- `CLAUDE.md` — Rules 섹션에 두 신규 rule 에 대한 인덱스 항목 추가.
- `.claude/rules/workflow.md` — "Cross-Layer Isolation" 바로 앞에 "Task Report (Mandatory)" 섹션 삽입하여 9-step flow 흐름에 편입.
- (간접) `.claude/rules/worktree-parallel.md` — 직접 수정 없음. `claude-config-sync.md` 가 상위 규칙으로서 startup ritual 을 구체화한다.

상기 작업 자체가 `claude-config-sync.md` 가 정의한 "즉시 push" 대상이므로, 본 보고서 작성 후 한 커밋으로 묶어 rebase-retry push 한다.

## Verification

- 생성 파일 존재 확인:
  ```bash
  ls .claude/rules/worktree-task-report.md .claude/rules/claude-config-sync.md
  ```
- CLAUDE.md 에 두 rule 항목이 표기됨:
  ```bash
  grep -E "worktree-task-report|claude-config-sync" CLAUDE.md
  ```
- `workflow.md` 에 "Task Report" 섹션 삽입됨:
  ```bash
  grep -n "Task Report" .claude/rules/workflow.md
  ```
- **수동 확인 필요 (사용자)**: claude role 의 변경이 origin/main 에 push 된 후, `backend`/`front`/`qa`/`debug`/`feature` 워크트리를 재시작하거나 새 `claude` 세션을 열면 신규 rule 이 컨텍스트에 로드되는지.

## Follow-ups / 재발 방지

- **[중요] 다른 세션 재시작 필요**: 현재 `backend`, `front`, `qa`, `debug`, `feature` 워크트리에서 돌고 있는 기존 Claude Code 세션이 있다면 **한 번 재시작** 해야 `worktree-task-report.md` 와 `claude-config-sync.md` 가 완전히 적용된다. 파일 시스템 rebase 만으로는 세션 내부 rule 캐시는 갱신되지 않을 수 있다.
- 이후 새 rule/agent/skill 을 claude role 에서 추가·수정할 때마다 `claude-config-sync.md` 에 따라 **즉시** commit + rebase-retry push.
- `workflow.md` 의 Gate Rules Summary 표에 "Task Report 존재 여부" 행을 향후 추가하는 것을 고려 (이번 변경에서는 본문 섹션 추가로 대체).
- 사용자 관찰 필요: 에이전트들이 실제로 sync-before-work 를 수행하는지. 누락 사례 발견 시 해당 에이전트 정의 파일에 명시적으로 지시를 추가해 보강.

## Related

- Rule: `.claude/rules/worktree-task-report.md` (신규)
- Rule: `.claude/rules/claude-config-sync.md` (신규)
- 참조 규칙: `.claude/rules/worktree-parallel.md`, `.claude/rules/workflow.md`, `.claude/rules/agents.md`
- 같은 날 보고서: `docs/reports/2026-04-11-claude-worktrees-statusline-fix.md`
- 메모리: `feedback_per_task_worktree_report.md`
