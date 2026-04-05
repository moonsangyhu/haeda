---
paths:
  - "server/**"
---

# Server (FastAPI) Rules

This file auto-loads when working in the server/ directory.

## Pre-Implementation Checklist

1. Verify endpoint is defined in `docs/api-contract.md`
2. Verify entity/fields are defined in `docs/domain-model.md`
3. Verify P0 scope — P1 endpoints (GET /challenges public list, /devices, push) are forbidden

## Code Rules

- Response envelope: `{"data": ...}` / `{"error": {"code": "...", "message": "..."}}`
- Error codes: Use only UPPER_SNAKE_CASE codes defined in api-contract.md
- Auth: Bearer token -> `request.state.user_id`
- DB schema changes -> always use Alembic migrations
- Table names: snake_case plural, UUID PK, TIMESTAMPTZ timestamps
- Business logic (achievement rate, all-verified check): see domain-model.md §4

## Forbidden

- Do not modify docs/ files
- Do not modify app/ (Flutter) code
- Do not create endpoints not in api-contract.md
- Do not add tables/columns not in domain-model.md
- Do not hardcode secrets in .env
