---
paths:
  - "docs/**"
---

# Docs Protection Rules

The docs/ directory is the **Source of Truth** for this project.

## Rules

- docs/ files must not be modified in principle.
- When code and docs conflict, **docs are correct** — modify the code.
- If docs modification is unavoidable, explain the reason to the user and get explicit approval.
- Even typo corrections require user confirmation before proceeding.

## Included Files

- `prd.md` — feature list, P0/P1 scope, non-functional requirements
- `user-flows.md` — screen flows, screen structure
- `domain-model.md` — entities, fields, business rules
- `api-contract.md` — REST endpoints, request/response schemas, error codes

## Exceptions

- `docs/reports/` — feature-flow 워크플로에서 자동 생성되는 보고서 디렉토리. 자유롭게 생성/수정 가능.
