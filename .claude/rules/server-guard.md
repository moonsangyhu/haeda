---
paths:
  - "server/**"
---

# Server (FastAPI) 작업 규칙

이 파일은 server/ 디렉토리 작업 시 자동으로 로딩된다.

## 구현 전 필수 확인

1. 엔드포인트가 `docs/api-contract.md`에 정의되어 있는지 확인
2. 엔터티/필드가 `docs/domain-model.md`에 정의되어 있는지 확인
3. P0 범위인지 확인 — P1 엔드포인트(GET /challenges 공개목록, /devices, 푸시)는 구현 금지

## 코드 규칙

- 응답 envelope: `{"data": ...}` / `{"error": {"code": "...", "message": "..."}}`
- 에러 코드: api-contract.md에 정의된 대문자 스네이크케이스만 사용
- 인증: Bearer 토큰 → `request.state.user_id`
- DB 스키마 변경 → 반드시 Alembic 마이그레이션
- 테이블명: snake_case 복수형, UUID PK, TIMESTAMPTZ timestamps
- 비즈니스 로직(달성률, 전원 인증 판정): domain-model.md §4 참조

## 금지

- docs/ 파일 수정 금지
- app/ (Flutter) 코드 수정 금지
- api-contract.md에 없는 엔드포인트 생성 금지
- domain-model.md에 없는 테이블/컬럼 추가 금지
- .env에 시크릿 하드코딩 금지
