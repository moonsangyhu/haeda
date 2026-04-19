# 테스트 케이스 추가 의무 강화 — 에이전트/스킬 규칙 업데이트

- **Date**: 2026-04-19
- **Worktree (수행)**: `.claude/worktrees/claude` (role: claude)
- **Worktree (영향)**: backend, front, qa, feature — 다음 `git fetch origin main && git rebase origin/main` 이후 자동 반영
- **Role**: claude (config sync)

## Request

사용자 요청 (2026-04-19):

> 지금 어떤 기능을 구현하거나 개선할 때, 각 구현 에이전트가 해당 기능에 대해 qa 를 진행할 수 있도록 테스트 케이스를 추가하고 있는지 확인해줘. 하지 않고 있다면, 반드시 테스트 케이스를 추가하도록 개선해줘

## Root Cause / Context

조사 결과, 구현 에이전트의 테스트 의무는 **부분적으로 이미 존재**했으나 다음 공백이 있었다.

1. **MVP 스킬에 테스트 규칙 부재** — `.claude/skills/fastapi-mvp/SKILL.md`, `.claude/skills/flutter-mvp/SKILL.md` 는 디렉토리 구조·패턴만 정의하고 테스트 요건이 전무했다. 빌더가 스킬만 참조하고 에이전트 문서를 건너뛰는 경로로 테스트가 누락될 수 있었다.
2. **Phase 3 순서 문제** — backend/flutter builder 모두 `Run tests → Write tests` 순으로 적혀 있어 테스트 우선 원칙이 불명확했다.
3. **Completion Output `### Tests` 섹션의 강제력 부족** — "Test files written, pass/fail counts" 같은 모호한 문구만 있어서 엔드포인트·스크린별 대응이 보장되지 않았다.
4. **code-reviewer 가 테스트 존재 여부를 검사하지 않음** — 정적 품질 게이트지만 "신규 엔드포인트/스크린에 대응 테스트가 있는가" 는 blocking 기준에 없었다. 공백이 QA 단계에서만 드러나 리워크 유발.
5. **qa-reviewer 체크리스트 `Tests exist (pytest / widget test)` 가 모호** — 테스트 한 개만 있어도 통과 가능한 수준의 문구였다.

현재 실제 커버리지: backend pytest 13 파일, Flutter widget test 17 파일. 관행은 지켜지고 있으나 규정화가 느슨했다.

## Actions

총 6개 파일 수정 + 1개 보고서 (본 파일).

- `.claude/skills/fastapi-mvp/SKILL.md` — `## Test Requirements (MANDATORY)` 섹션 신설. 엔드포인트별 최소 2건(happy + error), 서비스 로직 unit 테스트, 기존 픽스처 재사용, `uv run pytest` 전원 통과 기준 명시.
- `.claude/skills/flutter-mvp/SKILL.md` — `## Test Requirements (MANDATORY)` 섹션 신설. 스크린별 widget 테스트 최소 1건(렌더 + 상호작용), provider/공용 위젯 unit 테스트, `flutter analyze` + `flutter test` 기준 명시.
- `.claude/agents/backend-builder.md` — Phase 3 를 "Tests First" 로 재구성. Write 먼저 → Run → Migration → N+1 순서. Completion Output 의 `### Tests` 를 `### Tests Added (MANDATORY)` 로 변경하고 엔드포인트별 테스트 함수 목록을 요구.
- `.claude/agents/flutter-builder.md` — 동일 방식으로 Phase 3 재구성 및 Completion Output 강화.
- `.claude/agents/code-reviewer.md` — Review Criteria 에 `### 8. Test Coverage (Blocking)` 신설. `git diff --name-only HEAD` 기반으로 신규 엔드포인트/스크린 파일과 신규 테스트 파일을 대조, 누락 시 blocking. Verdict Rules 의 Blocking issues 목록에 "Missing tests for new endpoint / screen / service (section 8)" 추가.
- `.claude/agents/qa-reviewer.md` — 체크리스트의 모호했던 `Tests exist (pytest / widget test)` 를 3개 항목으로 분리: 엔드포인트별 happy+error pytest / 스크린별 widget 테스트 / 빌더의 `### Tests Added` 섹션 존재.

## Verification

- [x] `.claude/skills/fastapi-mvp/SKILL.md` 에 `Test Requirements (MANDATORY)` 섹션 추가 확인.
- [x] `.claude/skills/flutter-mvp/SKILL.md` 에 `Test Requirements (MANDATORY)` 섹션 추가 확인.
- [x] `.claude/agents/backend-builder.md` Phase 3 에 "Write tests first (MANDATORY)" 문구 추가, Completion Output 에 `### Tests Added (MANDATORY)` 섹션 반영.
- [x] `.claude/agents/flutter-builder.md` Phase 3 에 "Write widget tests first (MANDATORY)" 문구 추가, Completion Output 에 `### Tests Added (MANDATORY)` 섹션 반영.
- [x] `.claude/agents/code-reviewer.md` 에 `### 8. Test Coverage (Blocking)` 섹션과 Blocking issues 목록 갱신 반영.
- [x] `.claude/agents/qa-reviewer.md` 체크리스트 3개 항목으로 구체화 반영.
- [ ] **사용자 확인 필요** — 다음 feature/fix 실행 시 빌더 completion output 에 `### Tests Added` 가 포함되는지, code-reviewer 가 누락을 blocking 으로 반려하는지 실제 흐름에서 관찰 필요. 본 워크트리에서 end-to-end 재현은 불가.

## Follow-ups

- **다른 워크트리의 기존 세션은 재시작 필요** — `.claude/rules/claude-config-sync.md` §4 에 따라, `.claude/agents/**`, `.claude/skills/**` 변경은 파일 rebase 만으로는 세션 내부의 에이전트 캐시에 완전히 반영되지 않을 수 있다. feature/backend/front/qa 세션을 이미 띄워둔 경우 본 PR 머지 후 **세션 재시작 권장**.
- 회귀 테스트 관련 `.claude/agents/debugger.md:257` ("Add regression tests as specified in the plan") 는 이미 강제력이 충분하므로 추가 수정 없음.
- `.claude/rules/workflow.md` 의 "Verification Principles" 원칙 (pytest / flutter test 결과 인용 의무) 은 본 변경과 충돌 없이 그대로 유지.

## Related

- `.claude/rules/agents.md` — 10-agent 팀 dispatch 규칙과 gate 정의
- `.claude/rules/workflow.md` — 9-step slice flow 의 Step 3/4/5 (Implement → Code Review → QA) 가이드
- `.claude/rules/worktree-task-report.md` — 본 보고서 포맷의 출처
- `.claude/rules/claude-config-sync.md` — claude role 의 즉시 push 의무, 다른 세션 재시작 고지 의무
- Plan 파일: `/Users/yumunsang/.claude/plans/goofy-plotting-brooks.md` (본 작업 계획서)
