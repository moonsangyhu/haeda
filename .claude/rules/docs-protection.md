---
paths:
  - "docs/**"
---

# Docs Protection Rules

The docs/ directory is the **Source of Truth** for this project.

## Rules

- docs/ 파일은 자유롭게 수정 가능하되, Source of Truth 임을 인지하고 신중하게 변경한다.
- 코드와 docs 가 충돌하면 **docs 를 기준으로** 코드를 맞추는 것이 원칙이나, 기능구현·디자인 과정에서 docs 업데이트가 필요하면 함께 수정한다.
- 대규모 구조 변경(섹션 삭제, 스키마 재설계 등)은 사용자에게 사전 고지한다.

## Source of Truth Files

- `prd.md` — feature list, P0/P1 scope, non-functional requirements
- `user-flows.md` — screen flows, screen structure
- `domain-model.md` — entities, fields, business rules
- `api-contract.md` — REST endpoints, request/response schemas, error codes

## Freely Writable

- `docs/reports/` — 자동 생성 보고서
- `docs/planning/` — 기능 기획 문서
- `docs/design/` — 디자인 스펙 문서
