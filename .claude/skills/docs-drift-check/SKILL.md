---
name: docs-drift-check
description: 구현된 코드가 docs(api-contract, domain-model, user-flows)와 일치하는지 확인하는 정합성 점검
---

# Docs Drift Check

구현된 코드가 source of truth 문서와 일치하는지 체계적으로 확인한다.
`/mvp-slice-check`가 슬라이스 완성도를 보는 거라면, 이 스킬은 **코드 ↔ docs 정합성**에 집중한다.

## 사용법

```
/docs-drift-check                          # 전체 확인
/docs-drift-check 챌린지 생성               # 특정 슬라이스만
/docs-drift-check server/app/routers/      # 특정 디렉토리만
```

## 점검 항목

### 1. API 경로 drift (api-contract.md ↔ server/app/routers/)

- 문서에 정의된 P0 엔드포인트가 모두 구현되었는가
- 코드에 문서에 없는 엔드포인트가 존재하는가
- HTTP method가 일치하는가
- 경로 파라미터명이 일치하는가

**확인 방법**: api-contract.md의 엔드포인트 목록을 추출하고, routers/ 디렉토리의 `@router.get|post|put|delete` 데코레이터를 grep하여 대조한다.

### 2. 응답 스키마 drift (api-contract.md ↔ server/app/schemas/)

- 응답 필드명이 일치하는가
- 필드 타입이 일치하는가 (string, integer, boolean, array 등)
- 필수/선택 구분이 일치하는가
- envelope 형식(`data`/`error`)이 올바른가

### 3. DB 모델 drift (domain-model.md ↔ server/app/models/)

- 테이블명이 일치하는가
- 컬럼명과 타입이 일치하는가
- UNIQUE, NOT NULL, FK 제약 조건이 일치하는가
- 인덱스가 문서에 명시된 대로 있는가

### 4. 에러 코드 drift (api-contract.md ↔ 코드 전체)

- 코드에서 사용하는 에러 코드가 문서에 정의된 것만인가
- 문서의 HTTP status ↔ 에러 코드 매핑이 일치하는가

### 5. 화면 플로우 drift (user-flows.md ↔ lib/features/)

- 문서에 정의된 화면이 모두 구현되었는가
- 화면 간 이동(네비게이션)이 문서와 일치하는가
- 달력 표시 규칙(빈칸/썸네일/계절아이콘)이 올바른가

## 출력 형식

```
## Docs Drift 점검 결과

### 점검 범위
(전체 / 특정 슬라이스 / 특정 디렉토리)

### API 경로
- ✅ 일치: (N개 엔드포인트)
- ❌ 미구현: (목록)
- ⚠️ 문서에 없음: (목록)

### 응답 스키마
- ✅ 일치: (N개)
- ❌ 불일치: (필드명/타입 차이 목록)

### DB 모델
- ✅ 일치: (N개 테이블)
- ❌ 불일치: (컬럼/제약 차이 목록)

### 에러 코드
- ✅ 일치: (N개)
- ⚠️ 문서에 없는 코드: (목록)

### 화면 플로우
- ✅ 일치: (N개 화면)
- ❌ 미구현: (목록)

### 요약
- drift 없음 / drift N건 발견
- (수정이 필요한 경우 파일:라인 목록)
```
