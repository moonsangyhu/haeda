# feat: add nudge (콕 찌르기) and notifications system

- **Date**: 2026-04-09
- **PR**: #3 — https://github.com/moonsangyhu/haeda/pull/3
- **Branch**: feat/nudge-and-notifications
- **Area**: both

## What Changed

Added a "nudge" (콕 찌르기) feature where challenge members can poke others who haven't verified today (once per day per sender-receiver-challenge). Also built the in-app notification infrastructure (Notification table, REST API, Flutter notifications tab with unread badge).

## Changed Files

| File | Change |
|------|--------|
| `server/app/models/nudge.py` | New Nudge model with unique constraint for daily limit |
| `server/app/models/notification.py` | New Notification model for in-app notifications |
| `server/app/models/__init__.py` | Register Nudge and Notification models |
| `server/app/schemas/nudge.py` | NudgeSendRequest/Response Pydantic schemas |
| `server/app/schemas/notification.py` | NotificationItem/ListResponse schemas |
| `server/app/services/nudge_service.py` | send_nudge with 6-step validation + notification creation |
| `server/app/services/notification_service.py` | get_notifications, mark_as_read, get_unread_count |
| `server/app/routers/challenges.py` | Added POST /{id}/nudge endpoint |
| `server/app/routers/notifications.py` | New router: GET /notifications, PUT /{id}/read, GET /unread-count |
| `server/app/main.py` | Register notifications router |
| `server/alembic/versions/20260409_0000_004_...py` | Migration: nudges + notifications tables |
| `app/lib/features/challenge_space/models/nudge_data.dart` | Freezed models for nudge data |
| `app/lib/features/challenge_space/providers/nudge_provider.dart` | sendNudge function + receivedNudgesProvider |
| `app/lib/features/challenge_space/widgets/nudge_bottom_sheet.dart` | Bottom sheet with unverified members + nudge buttons |
| `app/lib/features/challenge_space/widgets/nudge_banner.dart` | Banner showing received nudges in challenge space |
| `app/lib/features/challenge_space/screens/challenge_space_screen.dart` | Integrated banner + nudge button in TodaySection |
| `app/lib/features/notifications/models/notification_data.dart` | Freezed models for notification data |
| `app/lib/features/notifications/providers/notification_provider.dart` | notificationListProvider + unreadCountProvider |
| `app/lib/features/notifications/screens/notifications_screen.dart` | Full notifications list screen (replaced placeholder) |
| `app/lib/core/widgets/main_shell.dart` | Added unread count badge on notifications nav icon |
| `app/lib/app.dart` | Switched to NotificationsScreen from placeholder |

## Implementation Details

- **Nudge validation**: 6-step pipeline — self-nudge check, challenge exists+active, sender member, receiver member, receiver not verified today, not already nudged today
- **DB constraints**: `uq_nudge_per_day` unique constraint on (sender_id, receiver_id, challenge_id, date) ensures once-per-day at DB level
- **Notification creation**: Nudge service creates both Nudge and Notification records in a single transaction
- **Frontend unverified member computation**: Uses existing calendar API data (members - today's verified_members) — no new endpoint needed
- **Error handling**: NudgeBottomSheet catches DioException, extracts ApiException code, shows Korean snackbar messages
- **Notification screen**: Full implementation with read/unread indicators, time-ago display, type-based icons, pull-to-refresh

## Tests & Build

- Analyze: 0 errors (117 pre-existing info/warnings)
- Tests: backend pytest not available locally (uv not in PATH), API manually verified via curl
- Build: flutter build web pass, docker compose up --build pass
- API verification: self-nudge 400, nudge success 201, duplicate 409, notifications list/unread-count all working
