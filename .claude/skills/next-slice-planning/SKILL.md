---
name: next-slice-planning
description: 현재까지 완료된 slice와 docs source of truth를 바탕으로 다음 slice를 추천하고, backend/frontend/qa 병렬 탭 프롬프트 3개를 생성한다.
allowed-tools: "Bash Read Glob Grep"
argument-hint: "[current-slice-name]"
---

# Next Slice Planning

QA 완료 후 또는 독립적으로, 다음에 진행할 slice를 추천하고
병렬 탭(backend/frontend/qa)에 바로 붙여넣을 프롬프트를 생성한다.

## 사용법

```
/next-slice-planning slice-06
/next-slice-planning            # current slice 생략 시 자동으로 최신 완료 slice 감지
```

인자: `$ARGUMENTS`

---

## 실행 절차

### Step 0: 인자 파싱

`$ARGUMENTS`에서 현재 slice 이름을 추출한다.
- 생략하면 `test-reports/` 디렉토리에서 가장 최근 완료된 slice를 자동 감지한다.

### Step 1: 완료 현황 파악

1. **test-reports 읽기**:
   ```bash
   ls test-reports/
   ```
   각 report를 읽어 판정(완료/부분 완료/미완료) 확인.

2. **코드 상태 확인**:
   ```bash
   ls server/app/routers/
   ls app/lib/features/
   ```
   실제 구현된 엔드포인트와 화면 확인.

3. **완료 slice 목록** 정리:
   ```
   | Slice | 판정 | 주요 내용 |
   |-------|------|----------|
   | slice-03 | 완료 | ... |
   | slice-04 | 완료 | ... |
   | ...   |      |          |
   ```

### Step 2: 미구현 P0 항목 식별

아래 docs를 읽고 아직 구현되지 않은 P0 항목을 추출:

1. **docs/prd.md** — P0 기능 목록에서 미구현 항목
2. **docs/api-contract.md** — P0 엔드포인트 중 아직 라우터가 없는 것
3. **docs/user-flows.md** — P0 플로우 중 아직 화면이 없는 것
4. **docs/domain-model.md** — P0 엔터티 중 아직 모델이 없는 것

### Step 3: 다음 Slice 결정

선택 규칙:
1. **순서 준수**: 이전 slice가 미완료(부분 완료 포함)이면 건너뛰지 않는다. 먼저 완료를 권장.
2. **의존관계**: 선행 엔드포인트/모델에 의존하는 slice는 선행이 완료된 후에만 추천.
3. **P0만**: P1 기능은 절대 추천하지 않는다.
4. **단일 추천**: 기본 1개. 차선 후보가 있으면 한 줄로 언급.
5. **모든 P0 완료 시**: "MVP P0 기능이 모두 구현되었습니다." 출력 후 종료.

### Step 4: 프롬프트 생성

---

## 출력 형식

```
## 다음 Slice 추천

### 완료 현황

| Slice | 판정 | 주요 내용 |
|-------|------|----------|
| ... | ... | ... |

### 미구현 P0 항목

| # | 영역 | 항목 | 근거 문서 |
|---|------|------|----------|
| 1 | ... | ... | ... |

---

### 추천: {next-slice-name}

| 항목 | 내용 |
|------|------|
| 목표 | (한 줄 요약) |
| P0 근거 | prd.md §X |
| 의존 slice | (없으면 "없음") |

#### 포함 범위

- 엔드포인트: (api-contract.md에서)
- 화면: (user-flows.md에서)
- 엔터티/규칙: (domain-model.md에서)

#### 제외 범위

- (포함하지 않을 항목)

#### 차선 후보

- (있으면 한 줄. 없으면 "없음")

---

### Backend 탭 프롬프트

> **backend 탭**에 그대로 붙여넣으세요.

(코드 블록)

---

### Frontend 탭 프롬프트

> **frontend 탭**에 그대로 붙여넣으세요.

(코드 블록)

---

### QA 탭 프롬프트

> backend/frontend 완료 후, **QA 탭**에서 실행하세요.

(코드 블록)
```

---

## 탭 프롬프트 템플릿

### Backend 탭 프롬프트

~~~
## {next-slice-name} Backend 구현

### 사전 작업
- Plan Mode (Shift+Tab) 진입
- `/slice-planning {next-slice-name}` 실행하여 계획 수립
- `@spec-keeper` 로 계획 검증
- 계획 승인 후 구현 시작

### Source of Truth
- docs/api-contract.md — 엔드포인트, 요청/응답, 에러코드
- docs/domain-model.md — 엔터티, 필드, 비즈니스 규칙

### 목표
(구체적 backend 작업 요약)

### 구현할 엔드포인트
1. METHOD /path — 설명
2. ...

### 수정/생성 범위
- server/ 만 수정한다. app/ 은 절대 건드리지 않는다.
- (예상 파일 경로)

### 사용할 agent/skill
- `backend-builder` 에이전트 또는 직접 구현
- 규칙: `.claude/skills/fastapi-mvp/`

### 검증
- [ ] `cd server && uv run pytest -v --tb=short` 전체 통과
- [ ] `/docs-drift-check` 실행 → spec drift 0건
- [ ] `/mvp-slice-check {next-slice-name}` backend 항목 통과

### 완료 후
- `/role-scoped-commit-push backend` 으로 커밋
- QA 탭에서 리뷰 요청
~~~

### Frontend 탭 프롬프트

~~~
## {next-slice-name} Frontend 구현

### 사전 작업
- Plan Mode (Shift+Tab) 진입
- `/slice-planning {next-slice-name}` 실행하여 계획 수립
- `@spec-keeper` 로 계획 검증
- 계획 승인 후 구현 시작

### Source of Truth
- docs/user-flows.md — 화면 플로우, UI 구조
- docs/api-contract.md — 엔드포인트 요청/응답

### 목표
(구체적 frontend 작업 요약)

### 구현할 화면/위젯
1. 화면명 — user-flows.md Flow N 참조
2. ...

### 수정/생성 범위
- app/ 만 수정한다. server/ 는 절대 건드리지 않는다.
- (예상 파일 경로)

### 사용할 agent/skill
- `flutter-builder` 에이전트 또는 직접 구현
- 규칙: `.claude/skills/flutter-mvp/`

### 검증
- [ ] `cd app && flutter test` 전체 통과
- [ ] `/docs-drift-check` 실행 → spec drift 0건
- [ ] `/mvp-slice-check {next-slice-name}` frontend 항목 통과

### 완료 후
- `/role-scoped-commit-push front` 으로 커밋
- QA 탭에서 리뷰 요청
~~~

### QA 탭 프롬프트

~~~
@qa-reviewer {next-slice-name} 리뷰.

이 slice의 목표:
(목표 한 줄)

포함 범위:
(엔드포인트, 화면, 엔터티 목록)

아래 순서로 리뷰하라:
1. `/mvp-slice-check {next-slice-name}` 실행
2. `/docs-drift-check` 실행
3. `cd server && uv run pytest -v --tb=short` 실행
4. `cd app && flutter test` 실행
5. `/smoke-test` 실행
6. 체크리스트 기반 리뷰 수행
7. 판정 출력

완료 판정 시 `/slice-test-report {next-slice-name}` 실행하여 결과서 저장.
~~~

---

## 주의사항

- 이 skill은 **읽기 전용**이다. 코드를 수정하지 않는다.
- P1 기능을 추천하지 않는다.
- 미완료 slice를 건너뛰는 추천을 하지 않는다.
- docs에 없는 엔드포인트/화면/엔터티를 추천하지 않는다.
- 프롬프트는 반드시 코드 블록 안에 넣어 복붙 가능하게 한다.
