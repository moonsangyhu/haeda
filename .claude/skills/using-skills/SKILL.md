---
name: using-skills
description: 메타 스킬 — "적용 가능한 skill 은 반드시 호출한다" 원칙 + haeda 의 주요 스킬 발동 트리거 인덱스. 모든 세션 시작 시 참조.
---

# Using Skills — 메타 스킬

**"If a skill applies, you MUST use it."**

스킬은 참고 자료가 아니라 **강제 규약**이다. 1% 확률로라도 적용 상황에 해당하면 호출해야 한다. 스킬의 존재를 알면서 호출하지 않는 것은 워크플로 위반이다. 이 원칙은 superpowers 의 메타 스킬에서 차용했으며, haeda 워크플로우에 동일하게 적용된다.

이 스킬 자체는 **직접 호출할 일이 거의 없다**. Main 이 "스킬을 어떻게 다뤄야 하는지" 를 알고 있게 하는 기준 문서.

## 원칙

1. **스킬 존재 = 호출 의무.** 발동 트리거와 일치하면 무조건 호출.
2. **스킬은 잊지 말라.** 세션 시작 시 available skills 목록을 확인하고, 관련 트리거를 기억.
3. **중복 호출 금지.** 이미 호출 중이거나 같은 스킬을 방금 수행했다면 다시 부르지 말 것.
4. **스킬이 부족하면 `skill-creator` (또는 `superpowers:writing-skills`) 호출.** 새 상황을 자주 마주치는데 마땅한 스킬이 없으면 신규 생성.

상세 트리거 색인은 `.claude/rules/superpowers-default.md` 와 `.claude/rules/language-policy.md` 참고.

## 일반 흐름 (superpowers)

| 트리거 | 호출할 스킬 |
|-------|-----------|
| 새 기능 / 모호한 아이디어 / "어떻게 할까" | `superpowers:brainstorming` |
| spec 보유 / plan 작성 차례 | `superpowers:writing-plans` |
| plan 실행 (단일 세션) | `superpowers:executing-plans` |
| plan 실행 (병렬 subagent) | `superpowers:subagent-driven-development` |
| production 코드 작성 / 수정 | `superpowers:test-driven-development` |
| 버그 / 테스트 실패 / 예상 외 동작 | `superpowers:systematic-debugging` |
| "완료" / "성공" / "pass" 주장 직전 | `superpowers:verification-before-completion` |
| 코드 리뷰 요청 / merge 전 | `superpowers:requesting-code-review` |
| 코드 리뷰 받은 후 | `superpowers:receiving-code-review` |
| 작업 종료 / merge 결정 | `superpowers:finishing-a-development-branch` |
| 워크트리 격리 필요 | `superpowers:using-git-worktrees` |
| 2 개 이상 독립 작업 병렬 | `superpowers:dispatching-parallel-agents` |
| 새 스킬 작성 / 수정 | `superpowers:writing-skills` 또는 `skill-creator` |

## haeda 로컬 스킬

| 트리거 | 호출할 스킬 |
|-------|-----------|
| `server/**` 변경 후 | `haeda-build-verify` |
| `app/**` 변경 후 | `haeda-ios-deploy` |
| commit + push (PR 자동 머지) | `commit` |
| rebase conflict | `resolve-conflict` |
| 로컬 docker compose 라이프사이클 | `local` |
| 통합 smoke check | `smoke-test` |
| 도메인 용어 / 시즌 아이콘 / MVP scope 확인 | `haeda-domain-context` |
| 스택별 구현 가이드 (FastAPI / Flutter) | `fastapi-mvp`, `flutter-mvp` |
| Claude Code 설정 / 룰 / 스킬 변경 | `set` |
| UI 디자인 | `frontend-design` |

## 한국어 산출물

모든 사용자 응답·산출물 문서·PR·commit 메시지는 한국어. 코드 식별자·error code·upstream/ARCHIVE 파일은 영어 유지. 자세한 건 `.claude/rules/language-policy.md`.

## 안 불러도 되는 경우

- **같은 스킬을 방금 수행**: 결과 그대로 사용.
- **트리거 미일치**: 애매하면 호출. 확실히 관계없으면 skip.
- **사용자가 명시적으로 skip 요청**: 예외. "이번은 스킬 없이 빠르게" — 이 경우 이유를 기록.

## Anti-Patterns

- 스킬 존재를 알면서 "이번엔 스킬 없이 빠르게" (사용자 지시가 없는 한 위반)
- 스킬 호출을 잊고 직접 즉흥 실행 — 결과가 형식을 벗어나 다음 단계에서 파싱 실패
- 스킬 설명만 읽고 실제 지시는 무시 — 각 스킬은 본문까지 끝까지 읽고 따를 것
- 스킬 여러 개를 중복 호출 — 한 번이면 충분

## 관련

- `.claude/rules/superpowers-default.md` — 기본 워크플로우 + 트리거 색인
- `.claude/rules/language-policy.md` — 한국어 정책
