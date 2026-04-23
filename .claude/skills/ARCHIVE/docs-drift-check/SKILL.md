---
name: docs-drift-check
description: Consistency check verifying implemented code matches docs (api-contract, domain-model, user-flows). Use after slice implementation or when code-docs mismatch is suspected.
allowed-tools: "Read Glob Grep"
argument-hint: "[slice-name or directory]"
---

# Docs Drift Check

Systematically verify that implemented code matches source of truth documents.
While `/mvp-slice-check` looks at slice completeness, this skill focuses on **code <-> docs consistency**.

## Usage

```
/docs-drift-check                          # full check
/docs-drift-check challenge-create         # specific slice only
/docs-drift-check server/app/routers/      # specific directory only
```

## Check Items

### 1. API Path Drift (api-contract.md <-> server/app/routers/)

- All P0 endpoints defined in docs are implemented
- No endpoints exist in code that aren't in docs
- HTTP methods match
- Path parameter names match

**Method**: Extract endpoint list from api-contract.md, grep `@router.get|post|put|delete` decorators in routers/ directory, and compare.

### 2. Response Schema Drift (api-contract.md <-> server/app/schemas/)

- Response field names match
- Field types match (string, integer, boolean, array, etc.)
- Required/optional distinction matches
- Envelope format (`data`/`error`) is correct

### 3. DB Model Drift (domain-model.md <-> server/app/models/)

- Table names match
- Column names and types match
- UNIQUE, NOT NULL, FK constraints match
- Indexes exist as specified in docs

### 4. Error Code Drift (api-contract.md <-> entire codebase)

- Error codes used in code are only those defined in docs
- HTTP status <-> error code mapping matches docs

### 5. Screen Flow Drift (user-flows.md <-> lib/features/)

- All screens defined in docs are implemented
- Screen navigation matches docs
- Calendar display rules (empty/thumbnail/season-icon) are correct

## Output Format

```
## Docs Drift Check Result

### Scope
(Full / specific slice / specific directory)

### API Paths
- Matched: (N endpoints)
- Not implemented: (list)
- Not in docs: (list)

### Response Schema
- Matched: (N)
- Mismatched: (field name/type difference list)

### DB Model
- Matched: (N tables)
- Mismatched: (column/constraint difference list)

### Error Codes
- Matched: (N)
- Not in docs: (list)

### Screen Flow
- Matched: (N screens)
- Not implemented: (list)

### Summary
- No drift / N drift items found
- (If fixes needed: file:line list)
```
