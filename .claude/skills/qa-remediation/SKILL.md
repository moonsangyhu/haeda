---
name: qa-remediation
description: QA 불완전 판정 후 backend/frontend 보완 프롬프트를 재생성한다. 기존 QA 결과나 test-report를 기반으로 병렬 탭에 내려보낼 표준 프롬프트를 만든다.
allowed-tools: "Bash Read Glob Grep"
argument-hint: "<slice-name>"
---

# QA Remediation Prompt Generator

QA 리뷰가 "부분 완료" 또는 "미완료" 판정을 내린 뒤,
보완 프롬프트를 (재)생성할 때 사용한다.

## 사용법

```
/qa-remediation slice-06
```

인자: `$ARGUMENTS`

---

## 용도

- `qa-reviewer`가 이미 보완 프롬프트를 출력했지만, 프롬프트를 다시 만들어야 할 때
- test-report에 blocking 항목이 남아 있어서 보완 프롬프트가 필요할 때
- 이전 QA 결과를 참고해서 후속 작업을 정리할 때

---

## 실행 절차

### Step 0: 인자 파싱

`$ARGUMENTS`에서 slice 이름을 추출한다.
- slice 이름이 없으면 → 에러 출력 후 중단:
  ```
  ❌ slice 이름을 지정해주세요.
  사용법: /qa-remediation <slice-name>
  예시: /qa-remediation slice-06
  ```

### Step 1: 기존 결과 수집

아래 소스에서 현재 slice의 불완전 항목을 수집한다:

1. **test-report 확인**:
   ```bash
   cat test-reports/{slice-name}-test-report.md
   ```
   - 판정이 "완료"이면 → 안내 후 종료:
     ```
     ℹ️ {slice-name}은 이미 "완료" 판정입니다. 보완이 필요 없습니다.
     ```

2. **현재 코드 상태 확인**:
   ```bash
   git status --porcelain
   git log --oneline -5
   ```

3. **Source of Truth 대조**:
   - `docs/api-contract.md` — 해당 slice의 엔드포인트 확인
   - `docs/domain-model.md` — 관련 엔터티/규칙 확인
   - `docs/user-flows.md` — 관련 화면 플로우 확인

### Step 2: 누락 항목 분석

test-report의 blocking/non-blocking 이슈와 코드 상태를 대조하여:

- **아직 해결되지 않은 항목**을 식별
- 각 항목을 **backend / frontend / qa** 영역으로 분류
- 근거 문서 섹션을 명시

### Step 3: 보완 프롬프트 생성

아래 형식으로 출력한다. **모든 섹션을 반드시 출력한다.**

---

## 출력 형식

```
## {slice-name} Remediation Prompts

### 현재 상태
- 판정: (부분 완료 / 미완료)
- Blocking 이슈: N건
- Non-blocking 이슈: N건

### 미해결 항목

| # | 영역 | 항목 | 심각도 | 상태 | 근거 문서 |
|---|------|------|--------|------|----------|
| 1 | backend | ... | blocking | 미해결 | api-contract.md §X |
| 2 | frontend | ... | non-blocking | 미해결 | user-flows.md §X |

---

### Backend 보완 프롬프트

> **backend 탭**에 그대로 붙여넣으세요.

(코드 블록으로 감싼 완전한 프롬프트)

- backend 누락이 없으면:
  ```
  ℹ️ Backend 보완 불필요. Frontend 보완만 진행하세요.
  ```

---

### Frontend 보완 프롬프트

> **frontend 탭**에 그대로 붙여넣으세요.

(코드 블록으로 감싼 완전한 프롬프트)

- frontend 누락이 없으면:
  ```
  ℹ️ Frontend 보완 불필요. Backend 보완만 진행하세요.
  ```

---

### 재검토 프롬프트

> 보완 완료 후 **QA 탭**에서 실행하세요.

(코드 블록으로 감싼 완전한 프롬프트)

---

### Test Report 갱신

- 보완 후 재검토에서 "완료" 판정 시:
  `/slice-test-report {slice-name}` 실행하여 최종 결과서 갱신
```

---

## 보완 프롬프트 템플릿

### Backend 보완 프롬프트 템플릿

~~~
## {slice-name} Backend 보완 작업

### Source of Truth
- docs/api-contract.md
- docs/domain-model.md

### 수정 범위
- server/ 만 수정한다. app/ 은 절대 건드리지 않는다.

### 수정 항목
1. (구체적 파일 경로 + 무엇을 어떻게 변경)
2. ...

### 사용할 agent/skill
- `backend-builder` 에이전트 또는 직접 구현
- 완료 후 `cd server && uv run pytest -v --tb=short`

### 검증
- [ ] pytest 전체 통과
- [ ] `/docs-drift-check` 실행 → spec drift 0건
- [ ] `/mvp-slice-check {slice-name}` 해당 항목 통과

### 완료 후
- `/role-scoped-commit-push backend` 으로 커밋
- QA 탭에서 재검토 요청
~~~

### Frontend 보완 프롬프트 템플릿

~~~
## {slice-name} Frontend 보완 작업

### Source of Truth
- docs/user-flows.md
- docs/api-contract.md

### 수정 범위
- app/ 만 수정한다. server/ 는 절대 건드리지 않는다.

### 수정 항목
1. (구체적 파일 경로 + 무엇을 어떻게 변경)
2. ...

### 사용할 agent/skill
- `flutter-builder` 에이전트 또는 직접 구현
- 완료 후 `cd app && flutter test`

### 검증
- [ ] flutter test 전체 통과
- [ ] `/docs-drift-check` 실행 → spec drift 0건
- [ ] `/mvp-slice-check {slice-name}` 해당 항목 통과

### 완료 후
- `/role-scoped-commit-push front` 으로 커밋
- QA 탭에서 재검토 요청
~~~

### 재검토 프롬프트 템플릿

~~~
@qa-reviewer {slice-name} 재검토.

이전 리뷰에서 아래 항목이 불완전 판정됨:
(미해결 항목 테이블 인용)

보완 작업 완료. 위 항목 중심으로 재검토하라.
추가로 아래도 확인하라:
- `/smoke-test` 결과
- `/docs-drift-check` 결과
보완 확인 시 "완료"로 판정 변경.
완료 판정 시 `/slice-test-report {slice-name}` 갱신.
~~~

---

## 주의사항

- 이 skill은 **읽기 전용**이다. 코드를 수정하지 않는다.
- 보완 프롬프트는 반드시 코드 블록 안에 넣어 복붙 가능하게 한다.
- 해당 영역에 누락이 없으면 "보완 불필요"를 명시한다. 섹션을 삭제하지 않는다.
- source of truth 문서 참조를 반드시 포함한다.
