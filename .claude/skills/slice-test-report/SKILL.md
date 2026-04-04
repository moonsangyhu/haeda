---
name: slice-test-report
description: 슬라��스 검증 완료 후 테스트 결과서를 생성/갱신하여 test-reports/에 저장한다. 슬라이스 구현 후, QA 리뷰 후, 또는 "테스트 결과서 작성해줘"라고 요청받았을 때 사용한다.
allowed-tools: "Bash Read Glob Grep Write Edit"
argument-hint: "[슬라이스명] (예: slice-03)"
---

# Slice Test Report

슬���이스 검증이 끝난 뒤, 결과를 `test-reports/` 디렉토리에 markdown 파일로 저장한다.
이 파일은 git에 커밋되어 향후 회귀 판단과 진행 이력의 근거가 된다.

## 사용법

```
/slice-test-report slice-03
/slice-test-report slice-04 --update    # 기존 파일 갱신
```

## 핵심 원칙

1. **실제 실행 결과만 기록한다.** 테스트를 직접 돌리고, 실제 출력을 근거로 작성한다.
2. **추정과 실측을 구분한다.** 직접 확인하지 못한 항목은 `[미확인]`으로 표시한다.
3. **실패를 숨기지 않는다.** 실패한 테스트가 있으면 그대로 기록한다.
4. **"모든 테스트 통과"는 실행 증거가 있을 때만 쓴다.** pytest/flutter test 출력의 passed/failed 숫자를 인용한다.

## 실행 절차

### Step 1: 테스트 실행

아래 명령을 순서대로 실행하고 결과를 수집한다:

```bash
# Backend 테스트
cd server && .venv/bin/python -m pytest -v 2>&1

# Flutter 테스트
cd app && flutter test 2>&1
```

### Step 2: 슬라이스 범위 확인

docs 4개 문서에서 이 슬라이스에 해당하는 엔드포인트, 화면, 에러 코드를 추출한다.

### Step 3: 결과서 작성/갱신

- 새 슬라이스: `test-reports/{슬라이스명}-test-report.md` 생성
- 재검증: 기존 파일의 테스트 결과 섹션과 날짜를 갱신

### Step 4: local smoke test 결과 추가 (선택)

smoke test를 실행했거나 이미 실행된 결과가 있으면 해당 섹션도 채운다.
실행하지 않았으면 `[미실행]`으로 표시한다.

## 파일 네이밍

```
test-reports/{슬라이스명}-test-report.md
```

예시:
- `test-reports/slice-01-test-report.md`
- `test-reports/slice-03-test-report.md`

## 결과서 템플릿

아래 구조를 따른다. 각 섹션을 빠짐없이 채운다.

```markdown
# {슬라이스명} 테스트 결과서

> 최종 업데이트: {YYYY-MM-DD}
> 판정: **완료** / **부분 완료** / **미완료**

## 슬라이스 개요

| 항목 | 내용 |
|------|------|
| 슬라이스 | {이름} |
| 목적 | {한 줄 설명} |
| 관련 Flow | user-flows.md Flow {N} |
| P0 여부 | P0 |

## 구현 범위

### Backend 엔드포인트

| 엔드포인트 | 상태 | 비고 |
|-----------|------|------|
| {METHOD /path} | 구현 완료 / 미구현 | |

### Frontend 화면

| 화면 | 라우트 | 상태 |
|------|--------|------|
| {화면명} | {/path} | 구현 완료 / 미구현 |

## 테스트 결과

### Backend 테스트

실행 명령: `cd server && .venv/bin/python -m pytest tests/{파일} -v`

| 테스트 | 결과 | 비고 |
|--------|------|------|
| {test_name} | PASS / FAIL | |

**요약**: {N} passed, {M} failed (pytest 출력 인용)

### Frontend 테스트

실행 명령: `cd app && flutter test test/{경로}`

| 테스트 | 결과 | 비고 |
|--------|------|------|
| {test_name} | PASS / FAIL | |

**요약**: {N} passed, {M} failed (flutter test 출력 인용)

### Local Smoke Test

| 항목 | 결과 | 확인 방법 |
|------|------|----------|
| {엔드포인트 or 흐름} | PASS / FAIL / [미실행] | curl / 브라우저 / [미확인] |

## 확인 구분

### 실제 확인한 것
- (직접 실행하여 확인한 항목)

### 미확인 / 추정
- (환경 한계 등으로 직접 확인하지 못한 항목, 추정 근거 포함)

## 이슈

### Blocking
- (있으면 기술, 없으면 "없음")

### Non-blocking
- (있으면 기술, 없으면 "없음")

## 판정

- **슬라이스 완료 여부**: 완료 / 부분 완료 / 미완료
- **다음 슬라이스 진행 가능**: 예 / 아니오
- **사유**: (판정 근거 한 줄)
```

## 주의사항

- `docs/` 디렉토리의 source of truth 문서는 수정하지 않는다.
- 결과서는 `test-reports/`에만 저장한다.
- 테스트를 실행하지 않고 결과서를 작성하지 않는다.
- 이전 슬라이스 결과서가 있으면 참고하되, 내용을 복사하지 않는다.
