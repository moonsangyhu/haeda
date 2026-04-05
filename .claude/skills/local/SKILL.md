---
name: local
description: Manage local dev environment (DB, Backend, Frontend) with docker compose — start/stop/status in one command.
allowed-tools: "Bash Read Glob Grep"
argument-hint: "[stop|status|reset|rebuild|rebuild backend|rebuild frontend]"
---

# Local Dev Environment Management (Container-First)

Manage the full stack (DB + Backend + Frontend) with `docker compose`.

## Subcommand Dispatch

- No argument or `up` -> **Start**
- `stop` -> **Stop**
- `status` -> **Status Check**
- `reset` -> **Reset** — delete volumes and restart
- `rebuild` -> **Rebuild** — rebuild with code changes and restart
- `rebuild backend` -> rebuild backend only
- `rebuild frontend` -> rebuild frontend only

Argument: `$ARGUMENTS`

---

## Start

### Step 1: Prerequisites Check

```bash
docker --version
docker compose version
```

If either is missing -> fail with Docker Desktop installation guidance.

### Step 2: docker compose up

```bash
cd /Users/moonsang.yhu/Documents/haeda && docker compose up --build -d
```

This single command:
1. Starts PostgreSQL + waits for healthcheck
2. Builds backend image -> migration -> seed -> starts uvicorn
3. Builds frontend image (Flutter web build + nginx) -> starts serving

**Important**: Build may take time. First build includes Flutter SDK download.
Set Bash tool timeout to 600000 (10 minutes).

### Step 3: Startup Verification

Run health checks after build completes:

```bash
# DB
pg_isready -h localhost -p 5432

# Backend
curl -s --max-time 10 http://localhost:8000/health

# Frontend
curl -s --max-time 5 -o /dev/null -w "%{http_code}" http://localhost:3000
```

### Step 4: Summary

```
## Local Dev Environment Start Result (Container-First)

| Service | Status | URL |
|---------|--------|-----|
| PostgreSQL | Started | localhost:5432 |
| Backend | Started | http://localhost:8000 |
| Frontend | Started | http://localhost:3000 |

### Endpoints
- Swagger UI: http://localhost:8000/docs
- Flutter app: http://localhost:3000
- Health: http://localhost:8000/health

### Test Accounts
| User | Bearer Token |
|------|-------------|
| Kim Cheolsu | 11111111-1111-1111-1111-111111111111 |
| Lee Younghee | 22222222-2222-2222-2222-222222222222 |
| Park Jimin | 33333333-3333-3333-3333-333333333333 |

### Commands
- Stop: `/local stop`
- Status: `/local status`
- Reset (delete data and restart): `/local reset`
- Logs: `docker compose logs -f [backend|frontend|db]`
```

Mark failed services with "Failed" and provide `docker compose logs <service>` guidance.

---

## Stop

```bash
cd /Users/moonsang.yhu/Documents/haeda && docker compose down
```

Summarize status after stop. Data is preserved in volumes.

---

## Status

```bash
# Container status
docker compose ps

# Individual health checks
pg_isready -h localhost -p 5432 2>&1
curl -s --max-time 3 http://localhost:8000/health 2>&1
curl -s --max-time 3 -o /dev/null -w "%{http_code}" http://localhost:3000 2>&1
```

Output format:
```
## Local Dev Environment Status

| Service | Container | Status | URL |
|---------|-----------|--------|-----|
| PostgreSQL | haeda-db-1 | up/down | localhost:5432 |
| Backend | haeda-backend-1 | up/down | http://localhost:8000 |
| Frontend | haeda-frontend-1 | up/down | http://localhost:3000 |
```

---

## Reset

Delete volumes and restart. All DB data is deleted.

```bash
cd /Users/moonsang.yhu/Documents/haeda && docker compose down -v && docker compose up --build -d
```

---

## Rebuild

Apply code changes to containers after slice implementation. DB data is preserved.

### Argument Parsing

- `rebuild` -> full rebuild (backend + frontend)
- `rebuild backend` -> backend only
- `rebuild frontend` -> frontend only

### Execution

**Full rebuild:**
```bash
cd /Users/moonsang.yhu/Documents/haeda && docker compose up --build -d backend frontend
```

**Backend only:**
```bash
cd /Users/moonsang.yhu/Documents/haeda && docker compose up --build -d backend
```

**Frontend only:**
```bash
cd /Users/moonsang.yhu/Documents/haeda && docker compose up --build -d frontend
```

Set Bash tool timeout to 600000 (10 minutes). (Frontend build may be slow)

### Startup Verification

Run health checks for rebuilt services:

```bash
# After backend rebuild
curl -s --max-time 10 http://localhost:8000/health

# After frontend rebuild
curl -s --max-time 5 -o /dev/null -w "%{http_code}" http://localhost:3000
```

### Output

```
## Rebuild Result

| Service | Status | Duration |
|---------|--------|----------|
| Backend | Rebuilt | ~Ns |
| Frontend | Rebuilt | ~Ns |

Refresh http://localhost:3000 in your browser.
```

---

## Notes

- First build may take 10+ minutes due to Flutter SDK download. Subsequent builds are fast with Docker cache.
- After frontend changes: `docker compose up --build -d frontend`
- After backend changes: `docker compose up --build -d backend`
- Reset DB data: `/local reset`
- Check logs: `docker compose logs -f backend`
