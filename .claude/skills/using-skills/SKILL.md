---
name: using-skills
description: 메타 스킬 — "적용 가능한 skill 은 반드시 호출한다" 원칙 + haeda 의 주요 스킬 발동 트리거 인덱스. 모든 agent 가 세션 시작 시 참조.
---

# Using Skills — 메타 스킬

**"If a skill applies, you MUST use it."**

스킬은 참고 자료가 아니라 **강제 규약**이다. 1% 확률로라도 적용 상황에 해당하면 호출해야 한다. 스킬의 존재를 알면서 호출하지 않는 것은 워크플로 위반이다. 이 원칙은 superpowers 의 메타 스킬에서 차용했으며, haeda 의 agent chain 에 그대로 적용된다.

이 스킬 자체는 **직접 호출할 일이 거의 없다**. 모든 agent / Main 이 "스킬을 어떻게 다뤄야 하는지" 를 알고 있게 하는 기준 문서.

## 원칙

1. **스킬 존재 = 호출 의무.** 발동 트리거와 일치하면 무조건 호출.
2. **스킬은 잊지 말라.** 세션 시작 시 available skills 목록을 확인하고, 관련 트리거를 기억.
3. **중복 호출 금지.** 이미 호출 중이거나 같은 스킬을 방금 수행했다면 다시 부르지 말 것.
4. **스킬이 부족하면 `skill-creator` 호출.** 새 상황을 자주 마주치는데 마땅한 스킬이 없으면 claude role 에서 skill-creator 로 신규 생성.

## haeda 스킬 발동 트리거 인덱스

아래 표는 주요 스킬이 **언제** 호출되어야 하는지의 기준이다. 애매하면 호출 쪽으로 판단.

### 설계 / 계획 단계

| 트리거 | 호출할 스킬 |
|-------|-----------|
| 사용자가 러프한 아이디어만 가져옴 ("X 기능 있으면 좋겠어") | `brainstorming` |
| 아이디어 → spec 문서로 뱅킹 | `plan-feature` |
| 뱅킹된 spec 구현 개시 | `implement-planned` |
| 디자인 스펙 구현 개시 | `implement-design` |
| 새 slice 시작 전 파일·엔드포인트·스크린 정리 | `slice-planning` |

### 구현 단계

| 트리거 | 호출할 스킬 |
|-------|-----------|
| production 코드 변경 (오타/포맷/코멘트 제외) | `tdd` (builder 가 자동 준수) |
| feature 전체 파이프라인 | `feature-flow` |
| bug fix 전체 파이프라인 | `fix` |
| 독립적 여러 문제 동시 처리 | `parallel-subagent-dispatch` |

### 디버깅 단계

| 트리거 | 호출할 스킬 |
|-------|-----------|
| 버그 재현 / 에러 분석 필요 | `systematic-debugging` (debugger agent 가 자동 준수) |
| QA verdict = partial / incomplete | `fix` → systematic-debugging |

### 검증 / 완료 단계

| 트리거 | 호출할 스킬 |
|-------|-----------|
| "완료", "pass", "성공" 주장 직전 | `verification-before-completion` |
| 슬라이스 완료 후 통합 smoke | `smoke-test` |
| 슬라이스 완료 후 test report 작성 | `slice-test-report` |
| 코드 ↔ docs drift 확인 | `docs-drift-check` |
| QA incomplete 후 재작업 prompt | `qa-remediation` |

### 문서화 단계

| 트리거 | 호출할 스킬 |
|-------|-----------|
| feature/fix 종료 후 보고서 + retrospective | `retrospective` (doc-writer 가 자동 호출) |
| docs/reports 작성 (일반) | `worktree-task-report.md` rule 대로 |

### 배포 / 커밋 단계

| 트리거 | 호출할 스킬 |
|-------|-----------|
| 로컬 dev 환경 컨트롤 | `local` |
| iOS simulator 직접 제어 | `sim` |
| 변경 묶어 PR 머지 | `commit` |
| role-scoped 커밋 (parallel worktree) | `role-scoped-commit-push` |
| rebase conflict 발생 | `resolve-conflict` |
| feature 롤백 | `rollback` |

### 다음 슬라이스

| 트리거 | 호출할 스킬 |
|-------|-----------|
| QA complete 이후 다음 slice 계획 | `next-slice-planning` |

## 안 불러도 되는 경우

- **같은 스킬을 방금 수행**: 다시 부르지 말 것. 결과 그대로 사용.
- **트리거 미일치**: 애매하면 호출. 확실히 관계없으면 skip.
- **사용자가 명시적으로 skip 요청**: 예외. "이번은 스킬 없이 빠르게" — 이 경우 그 이유를 기록.

## 새 상황 발견 시

반복되는 상황인데 적합한 스킬이 없다면:

1. `claude` role 워크트리로 이동
2. `skill-creator` 스킬 호출
3. 신규 스킬 파일 작성 + frontmatter description 에 트리거 명시
4. 본 문서의 인덱스 표에 행 추가
5. PR 생성 + 자동 머지 (`claude-config-sync.md` 의무)

## Agent 별 기본 스킬 로드

각 agent 는 자기 역할에 가장 관련 깊은 스킬을 시스템 프롬프트에 인라인 참조해 두어야 한다. (`.claude/agents/<name>.md` frontmatter 의 `skills:` 필드 또는 본문의 "관련 스킬" 섹션)

| Agent | 필수 참조 스킬 |
|-------|-------------|
| `backend-builder` | tdd, verification-before-completion |
| `flutter-builder` | tdd, verification-before-completion |
| `debugger` | systematic-debugging, tdd, verification-before-completion |
| `code-reviewer` | verification-before-completion |
| `spec-compliance-reviewer` | verification-before-completion |
| `qa-reviewer` | verification-before-completion |
| `deployer` | verification-before-completion |
| `doc-writer` | retrospective |
| `product-planner` | brainstorming |

## Anti-Patterns

- 스킬 존재를 알면서 "이번엔 스킬 없이 빠르게" (사용자 지시가 없는 한 위반)
- 스킬 호출을 잊고 직접 즉흥 실행 — 결과가 형식을 벗어나 다음 단계에서 파싱 실패
- 스킬 설명만 읽고 실제 지시는 무시 — 각 스킬은 본문까지 끝까지 읽고 따를 것
- 스킬 여러 개를 중복 호출 — 한 번이면 충분

## 관련 규칙

- `.claude/rules/agents.md` — agent dispatch chain
- `.claude/rules/workflow.md` — 9-step slice flow
- `.claude/rules/verification.md` — "완료" 주장 시 검증 강제
- `.claude/rules/tdd.md` — TDD 의무화 레벨
