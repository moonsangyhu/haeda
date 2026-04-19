# Task Report: Room Speech Backend Implementation

- **Date**: 2026-04-19
- **Worktree (수행)**: feature (worktree-feature)
- **Worktree (영향)**: feature
- **Role**: backend

## Request

Implement the backend half of the "Challenge Room Speech Bubble" P2 feature per the design spec at `docs/design/challenge-room-speech.md` and the approved plan.

## Root Cause / Context

The challenge room mini-room design spec (`challenge-room-speech.md`) required a new `RoomSpeech` entity so that members can post short speech bubble messages that persist until the next day cutoff. No backend infrastructure existed for this feature.

## Actions

### Files Created

- `server/app/models/room_speech.py` — SQLAlchemy 2.0 async model with UNIQUE `(challenge_id, user_id)` constraint and INDEX `(challenge_id, expires_at)`.
- `server/app/schemas/room_speech.py` — Pydantic v2 schemas: `RoomSpeechCreateRequest`, `RoomSpeechItem`, `RoomSpeechSubmitResult`, `RoomSpeechDeleteResult`.
- `server/app/services/room_speech_service.py` — Business logic: content normalization, membership guard, in-memory rate limiting (10s), `next_cutoff_at`-based TTL, upsert via select+update/insert pattern (SQLite-safe for tests), idempotent delete.
- `server/app/routers/room_speech.py` — `APIRouter` with GET/POST/DELETE `/challenges/{challenge_id}/room-speech`.
- `server/alembic/versions/20260419_0001_016_add_room_speech.py` — revision `016`, down_revision `015`. Creates `room_speech` table, unique constraint, and index.
- `server/tests/test_room_speech.py` — 12 test cases covering all endpoints and edge cases.

### Files Modified

- `server/app/models/__init__.py` — Added `RoomSpeech` import and export.
- `server/app/main.py` — Registered `room_speech.router`.
- `server/app/utils/time.py` — Added `next_cutoff_at(cutoff_hour, now)` helper with 30-second boundary guard.

## Verification

```
tests/test_room_speech.py - 12 passed
Full suite: 107 passed in 1.77s
```

All 12 new tests pass. Full suite regression: no failures.

Tests covered:
- POST normal submission
- POST empty content (SPEECH_EMPTY 422)
- POST 41-char content (SPEECH_TOO_LONG 422)
- POST with newline stripped
- POST non-member (SPEECH_NOT_MEMBER 403)
- POST rate limit (SPEECH_RATE_LIMITED 429)
- POST upsert (same user, content updated, 1 row)
- GET returns list with envelope
- GET excludes expired rows
- GET non-member (SPEECH_NOT_MEMBER 403)
- DELETE removes row
- DELETE idempotent (200 ok)

## Follow-ups

- Migration `016` must be applied on the real DB before deploying: `alembic upgrade head`.
- Rate limit uses module-level dict (single worker). For multi-worker, replace with Redis-based rate limiter.
- Frontend (flutter-builder) needs to implement `SpeechInputSheet`, `SpeechBubble`, and `RoomSpeechController` per the design spec.
- Other worktree sessions should restart or `git rebase origin/main` to pick up these changes.

## Related

- `docs/design/challenge-room-speech.md` — authoritative spec
- Migration: `server/alembic/versions/20260419_0001_016_add_room_speech.py`
