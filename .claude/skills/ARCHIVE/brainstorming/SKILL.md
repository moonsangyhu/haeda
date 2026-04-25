---
name: brainstorming
description: 러프한 아이디어를 구현 가능한 spec 으로 shaping 하는 대화형 9단계. plan-feature / product-planner 의 전처리. "대충 아이디어만 있어" 수준에서 시작할 때 가장 먼저 호출.
---

# Brainstorming Skill

사용자가 "이런 기능이 있으면 좋겠어" 수준의 러프한 아이디어를 가져왔을 때, 곧바로 `product-planner` 나 `plan-feature` 로 넘기지 않는다. 먼저 이 스킬을 호출해 아이디어를 **설계 가능한 형태**로 shaping 한다. 설계가 사용자에게 승인되기 전에는 **코드 작성을 시작하지 않는다.**

haeda 의 `plan-feature` 스킬이 템플릿 파일을 작성하는 **기계적 단계**라면, 본 스킬은 **질문과 대안 제안을 통해 아이디어를 다듬는 대화 단계**다.

## 원칙

1. **설계 승인 전 코드 금지.** Write/Edit 는 설계 문서 초안을 `docs/planning/drafts/<slug>.md` 로 쓰는 데만 사용한다. 소스 코드(`app/`, `server/`) 는 건드리지 않는다.
2. **사용자 의도를 넘겨짚지 않는다.** 애매하면 질문. 틀린 전제 위에 spec 을 쌓지 않는다.
3. **Trade-off 를 숨기지 않는다.** 2-3개의 대안을 제시하고 각자의 장단을 명시한다.
4. **기존 자산 우선.** 이미 있는 화면·모델·엔드포인트·스킬을 재사용할 수 있는지 반드시 확인.

## 9단계 워크플로우

### Step 1 — 맥락 파악
사용자가 준 아이디어를 한 문장으로 요약하고 불명확한 지점을 나열한다.
- 누가 사용하는가? (신규 사용자 / 기존 사용자 / 관리자)
- 언제 사용하는가? (특정 flow 의 어느 지점)
- 어떤 문제를 해결하는가? (PRD 의 어느 pain point)
- 성공 지표는? (정량 / 정성)

### Step 2 — 유사 사례 수집
- haeda `docs/prd.md`, `docs/user-flows.md` 에서 유사 기능 존재 여부 확인
- haeda `docs/planning/ideas/**`, `docs/planning/specs/**` 에 이미 뱅킹된 관련 아이디어
- 필요하면 외부 레퍼런스 조사 (competitor app, 디자인 패턴)

### Step 3 — 접근법 2-3개 제안
각 접근법마다:
- 한 줄 설명
- 소요 노력 (S / M / L)
- P0/P1 여부
- Trade-off (장점 2개, 단점 2개)
- 기존 자산 재사용 여부

### Step 4 — 사용자 선택 수용
사용자가 특정 접근을 고르거나, 새로운 5번째 방향을 제시할 수 있다. 사용자의 선택을 그대로 받아들인다 (설득하지 않음).

### Step 5 — Edge case 열거
선택된 접근에 대해:
- 실패 경로 (네트워크 끊김, 권한 없음, 데이터 없음)
- 빈 상태 / 0건 / 1건 / N건 의 UI
- 동시성 / 경쟁 조건
- 국제화 / 시간대 / 음수·0·매우 큰 값
- 접근성 (voiceover, 폰트 크기)

### Step 6 — UX flow sketch
화면/상호작용 순서를 글머리표로 작성.
- Entry point (어디서 진입하나)
- 메인 흐름 (3-5단계)
- 분기 (성공 / 실패 / 취소)
- Exit point (어디로 이어지나)

### Step 7 — Spec 문서화
`docs/planning/drafts/<slug>.md` 로 초안 작성. (feature 워크트리에서 실행 중이면 drafts 는 생략하고 바로 specs/ 로 가도 됨. planner 워크트리가 아니므로 hook 금지 없음.)

YAML frontmatter 는 `docs/planning/TEMPLATE.md` 를 따르되 `status: draft` 로 시작.

### Step 8 — 사용자 리뷰
작성한 draft 를 사용자에게 보여주고 피드백 받는다. 수정 반영 후 재확인.

### Step 9 — Promote to ready
사용자가 OK 하면 `status: draft → ready` 로 변경하고 `docs/planning/specs/<slug>.md` 로 이동. 그리고 `plan-feature` 또는 `product-planner` 스킬에 핸드오프.

## 적용 트리거

다음 상황에서 `product-planner` 대신 본 스킬을 먼저 호출한다:

- "X 기능 만들어줘" 만 있고 구체적 flow 없음
- "이런 느낌이면 좋겠는데" 같이 감성적 묘사
- 요구사항이 P0/P1 중 어느 쪽인지 불명
- 여러 구현 방법이 가능해 trade-off 선택이 필요
- 기존 기능과 관계가 불명 (통합 / 분리 / 대체?)

반대로 본 스킬을 **스킵**해도 되는 경우:

- 이미 `docs/planning/specs/<slug>.md` 가 `status: ready` 로 존재
- 사용자가 PRD 의 특정 섹션을 인용하며 "여기 나온 이거 구현해" 한 경우
- 명확한 bug fix (아이디어 shaping 불필요)

## 결과물

이 스킬의 산출물은 항상 `docs/planning/drafts/<slug>.md` 또는 `docs/planning/specs/<slug>.md` 단일 파일. 소스 코드는 건드리지 않는다.

핸드오프 후:
- `plan-feature` 스킬이 spec 을 최종 템플릿으로 정리
- `product-planner` 에이전트가 Feature Plan 형태로 실행 가능하게 변환
- 이후 `feature-flow` 스킬이 전체 파이프라인 오케스트레이션

## Never Do

- 소스 코드 파일 편집
- `docs/prd.md`, `docs/user-flows.md`, `docs/domain-model.md`, `docs/api-contract.md` 편집 (source of truth, 사용자 승인 필요)
- 사용자에게 접근법을 **강요** — 제안만 하고 선택은 사용자
- Edge case 를 생략하고 happy path 만 정리

## 관련

- `.claude/skills/plan-feature/SKILL.md` — 다음 단계
- `.claude/agents/product-planner.md` — 본 스킬 완료 후 호출
- `.claude/rules/planner-worktree.md` — planner 워크트리 역할
- `docs/planning/TEMPLATE.md` — spec 템플릿
