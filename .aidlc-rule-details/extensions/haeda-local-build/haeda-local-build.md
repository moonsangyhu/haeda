# Haeda Local Build Extension (ALWAYS-ENFORCED)

## Overview

Every AIDLC-driven code change that touches `server/**` MUST be verified by rebuilding the local Docker Compose stack and hitting the backend `/health` endpoint. Mock results, fallback paths, and "build-only" verification are not accepted as evidence of working behavior.

**Enforcement**: Applies at AIDLC's **Construction → Build and Test** stage. Non-compliance is a **blocking finding** — the stage MUST NOT present the "Ready to proceed to Operations stage" option until the rebuild and health check are cited.

## Scope

Triggered when the current AIDLC unit touches any of:
- `server/**` (FastAPI app, models, migrations, services, tests)
- `docker/**`, `docker-compose.yml`, `Dockerfile*`
- `server/alembic/versions/**`

If the unit is app-only (no server/ changes), this extension is **N/A** and the stage may skip the server rebuild — `haeda-flutter-ios-sim` still applies for app/ changes.

## Rule LOCAL-01: Docker Compose rebuild

**Rule**: Before declaring the Build and Test stage complete, the backend service MUST be rebuilt from the current source and brought up in detached mode.

**Required command** (from repo root):
```bash
docker compose up --build -d backend
```

**Verification**:
- Command was executed in this session
- Exit code 0
- Output excerpt cited showing the image layers rebuilt and the container transitioning to `Started` / `Running`
- No `ERROR` lines in the build output

## Rule LOCAL-02: Health endpoint probe

**Rule**: After rebuild, the `/health` endpoint MUST respond 200 OK within 30 seconds.

**Required command**:
```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8000/health
```

Also accept (with body):
```bash
curl -s http://localhost:8000/health | head -20
```

**Verification**:
- HTTP status `200`
- Body includes expected health payload (e.g., `{"status":"ok"}` or equivalent per current contract)
- If the endpoint has moved, reference the new path in the extension compliance summary and cite its response

## Rule LOCAL-03: Migration runtime verification

**Rule**: If the unit added or modified Alembic migration files (`server/alembic/versions/**`), `alembic upgrade head` MUST run cleanly inside the backend container as part of startup OR as an explicit step.

**Verification (either path)**:
- Container startup logs show `alembic upgrade head` completing without errors (cite the log line)
- OR the stage executed `docker compose exec backend alembic upgrade head` and cited its output

## Rule LOCAL-04: Evidence in Build and Test stage

The stage completion message MUST include a `### Local Build Verification` block with:

```markdown
### Local Build Verification — haeda-local-build

- **Rebuild**:
  - Command: `docker compose up --build -d backend`
  - Output (excerpt):
    ```
    => exporting to image
    [+] Running 2/2
     ✔ Container haeda-backend  Started   0.4s
    ```
- **Health**:
  - Command: `curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8000/health`
  - Output: `200`
- **Migrations**:
  - Command: (included in container startup, see logs)
  - Output (excerpt): `INFO  [alembic.runtime.migration] Running upgrade ... -> <rev>, <desc>`
```

## Rule LOCAL-05: Failure handling

If any of LOCAL-01 / LOCAL-02 / LOCAL-03 fails:
1. Do NOT proceed to the Operations stage placeholder
2. Return to the relevant Code Generation or Functional Design stage to fix the issue
3. Log the failure + remediation in `aidlc-docs/audit.md`

## N/A Cases

This extension is N/A when all of:
- The unit touched ONLY `app/**`, `docs/**`, `.claude/**`, `.aidlc-rule-details/**`, `aidlc-docs/**`, or tooling config with no runtime effect
- No `docker-compose.yml` / Dockerfile changes

In that case, compliance summary MUST record: `LOCAL-01..05 — N/A (no server/ changes in this unit)`.

## Compliance Summary Format

```
## Extension Compliance — haeda-local-build
- LOCAL-01 Docker rebuild: compliant — backend rebuilt, container Started
- LOCAL-02 Health probe: compliant — HTTP 200
- LOCAL-03 Migration runtime: compliant — alembic upgrade cited in startup logs
- LOCAL-04 Evidence format: compliant
- LOCAL-05 Failure handling: N/A — no failures
```
