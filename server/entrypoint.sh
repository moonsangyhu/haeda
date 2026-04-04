#!/bin/bash
set -e

echo "==> Running database migrations..."
uv run alembic upgrade head

echo "==> Seeding data..."
uv run python seed.py || echo "Seed completed (or already seeded)."

echo "==> Starting FastAPI server..."
exec uv run uvicorn app.main:app --host 0.0.0.0 --port 8000
