# Superpowers as Default Workflow

이 레포의 기본 워크플로우는 **superpowers** 플러그인 (`@claude-plugins-official/superpowers`). 모든 코딩 세션은 superpowers 메타 스킬이 자동 발동되는 흐름으로 진행된다.

## 폐기

- AI-DLC adaptive workflow — 2026-04-25 `git reset --hard pre-aidlc-migration` 으로 제거
- 11-agent feature-flow dispatch — `.claude/agents/ARCHIVE/`
- 10-step slice flow — `.claude/skills/ARCHIVE/feature-flow/`, `.claude/rules/ARCHIVE/workflow.md`
- 워크트리 role contract / planner-worktree / design-worktree — `.claude/rules/ARCHIVE/`

## 자동 발동 트리거 색인

| 사용자 발화 / 상황 | 발동 스킬 |
|------------------|----------|
| 새 기능 / 모호한 아이디어 / "어떻게 할까" | `superpowers:brainstorming` |
| 다단계 구현 spec 보유, plan 작성 차례 | `superpowers:writing-plans` |
| plan 보유, 실행 (단일 세션) | `superpowers:executing-plans` |
| plan 보유, 병렬 subagent 실행 | `superpowers:subagent-driven-development` |
| 코드 추가 / 버그 수정 (production) | `superpowers:test-driven-development` |
| 버그 / 테스트 실패 / 예상 외 동작 | `superpowers:systematic-debugging` |
| "완료" / "성공" / "pass" 주장 직전 | `superpowers:verification-before-completion` |
| 코드리뷰 요청 / merge 전 | `superpowers:requesting-code-review` |
| 코드리뷰 받은 후 | `superpowers:receiving-code-review` |
| 작업 종료 / merge 결정 | `superpowers:finishing-a-development-branch` |
| 격리된 worktree 필요 | `superpowers:using-git-worktrees` |
| 2 개 이상 독립 작업 병렬 | `superpowers:dispatching-parallel-agents` |
| 새 스킬 작성 / 기존 스킬 수정 | `superpowers:writing-skills` |

## haeda 로컬 스킬과의 분담

| 영역 | 발동 |
|------|------|
| 한국어 산출물 | `language-policy.md` (rule) |
| 도메인 식별자 / API envelope / 시즌 아이콘 | `coding-style.md` + `haeda-domain-context` (skill) |
| 백엔드 빌드 검증 | `haeda-build-verify` (skill) + `local-build-verification.md` |
| iOS simulator 배포 | `haeda-ios-deploy` (skill) + `ios-simulator.md` |
| commit / push (PR 자동 머지) | `commit` (skill) — `superpowers:finishing-a-development-branch` 후 호출 |
| rebase conflict | `resolve-conflict` (skill) |
| 로컬 dev 환경 | `local`, `smoke-test` (skills) |
| 새 스킬 작성 | `superpowers:writing-skills` 또는 `skill-creator` |

## "Skip Is Failure" 원칙

`using-skills` (haeda 메타 스킬) 의 원칙: 적용 가능한 스킬은 반드시 발동한다. superpowers 의 `using-superpowers` 와 동일.

## ARCHIVE 재진입 금지

`.claude/{agents,skills,rules}/ARCHIVE/` 의 파일은 참조 자료일 뿐, 실행 / 발동 대상 아님. 사용자가 명시적으로 "feature-flow 로 진행" 같이 요구하지 않는 한 진입하지 않는다.
