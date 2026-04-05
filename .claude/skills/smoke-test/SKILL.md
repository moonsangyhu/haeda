---
name: smoke-test
description: Local dev environment smoke test. Checks Docker Postgres, FastAPI backend, and Flutter web in order. Use after slice implementation to verify integration, or when asked to run a smoke test.
allowed-tools: "Bash Read Glob Grep"
---

# Local Smoke Test

Verify the full stack works correctly in local dev environment, in order.
Follows the execution order from `docs/local-dev.md`.

## Usage

```
/smoke-test              # full stack check
/smoke-test backend      # backend only
/smoke-test frontend     # frontend only
```

## Absolute Principles

- Execute actual commands and verify actual responses. Do not assume or guess success.
- If a step's success condition is not met, report failure immediately.
- If a previous step fails, do not proceed to the next step.
- Do not start services — only verify already-running services.
  (If a service is down, report failure and provide start command guidance)

## Check Order

### Step 1: PostgreSQL

```bash
pg_isready -h localhost -p 5432
```

- Success: "accepting connections" output
- Failure: Guide to run `docker compose up -d db`

### Step 2: Backend Health

```bash
curl -s http://localhost:8000/health
```

- Success: `{"status":"ok"}` response
- Failure: Guide to run `cd server && uv run uvicorn app.main:app --reload --port 8000`

### Step 3: Basic API Operation

Test with test user (Kim Cheolsu):

```bash
curl -s -H "Authorization: Bearer 11111111-1111-1111-1111-111111111111" \
  http://localhost:8000/api/v1/me/challenges
```

- Success: HTTP 200 + `{"data": ...}` response
- Failure: Check seed data -> Guide to run `cd server && uv run python seed.py`

### Step 4: Backend Tests

```bash
cd server && uv run pytest -v --tb=short
```

- Success: All tests pass
- Failure: Report failed test list

### Step 5: Flutter Build Check

```bash
cd app && flutter pub get && flutter build web --no-tree-shake-icons
```

- Success: Build succeeds (exit code 0)
- Failure: Report build errors

### Step 6: Flutter Tests

```bash
cd app && flutter test
```

- Success: All tests pass
- Failure: Report failed test list

## Output Format

```
## Smoke Test Result

### Environment
- PostgreSQL: pass/fail
- Backend: pass/fail
- API: pass/fail
- Backend tests: pass/fail (N passed, M failed)
- Flutter build: pass/fail
- Flutter tests: pass/fail (N passed, M failed)

### Overall Result: PASS / FAIL

### Failed Items (if any)
- (Failed step + error message + resolution)
```
