---
name: mvp-slice-check
description: Vertical slice completion checklist (manual execution only)
disable-model-invocation: true
---

# MVP Vertical Slice Check

Checklist to verify whether a vertical slice (feature unit) is complete.
Execute only when user calls `/mvp-slice-check` or invokes directly.

## Check Items

### 1. API Contract

- [ ] Endpoint is defined in `docs/api-contract.md`
- [ ] Request/response schema matches docs
- [ ] Error codes use only those defined in docs
- [ ] Response envelope (`data` / `error`) format is correct

### 2. Domain Model

- [ ] DB model fields match `docs/domain-model.md`
- [ ] Constraints (UNIQUE, NOT NULL, FK) are applied
- [ ] Alembic migration is created

### 3. Backend

- [ ] Router is registered
- [ ] Business logic is separated into service layer
- [ ] Auth (Bearer token) dependency is applied
- [ ] pytest endpoint tests exist

### 4. Frontend

- [ ] Screen matches `docs/user-flows.md` flow
- [ ] API calls use correct endpoints
- [ ] Error states (loading, empty, error) are handled
- [ ] Widget tests exist

### 5. Integration

- [ ] Full flow works: frontend -> backend -> DB
- [ ] No P1 features included
- [ ] No hardcoded secrets

## Usage

Call with the slice name:

```
Check this slice: challenge creation (POST /challenges + challenge creation screen)
```
