# Coding Style & Implementation Rules

## Terminology

Class names, variable names, API paths follow English terms from docs:
Challenge, Verification, DayCompletion, ChallengeMember, Comment.

## API Contract Format

- Response envelope: `{"data": ...}` / `{"error": {"code": "...", "message": "..."}}`
- Error codes: UPPER_SNAKE_CASE, defined in `docs/api-contract.md`
- Paths, field names, types must match `api-contract.md` exactly

## Season Icons

| Season | Months |
|--------|--------|
| Spring | Mar-May |
| Summer | Jun-Aug |
| Fall | Sep-Nov |
| Winter | Dec-Feb |

## File & Function Size

| Metric | Recommended | Maximum |
|--------|-------------|---------|
| Lines per file | 200-400 | 800 |
| Lines per function | 10-30 | 50 |
| Nesting depth | 2-3 | 4 |
| Parameters | 3-4 | 6 |

If a function name contains "and" -> split it. If nesting exceeds 3 -> early return.

## Stack-Specific Rules

- **Flutter**: Feature-first structure, Riverpod, GoRouter, dio. Detail in `.claude/skills/flutter-mvp/`
- **FastAPI**: SQLAlchemy 2.0 async, Pydantic v2, Alembic. Detail in `.claude/skills/fastapi-mvp/`
