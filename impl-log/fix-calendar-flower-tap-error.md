# fix(app): prevent completion screen navigation on active challenges

- **Date**: 2026-04-11
- **Commit**: 54cea42
- **Area**: frontend

## What Changed

Tapping a completed-day flower icon on the calendar of an active challenge caused a 400 error (`CHALLENGE_NOT_COMPLETED`) because the app navigated to the completion screen, which requires the challenge to have ended. Added a `status == 'completed'` check so that active challenges navigate to the daily verifications screen instead.

## Changed Files

| File | Change |
|------|--------|
| `app/lib/features/challenge_space/screens/challenge_space_screen.dart` | Added `status == 'completed'` condition to `_onDayTap` allCompleted check (line 215) |

## Implementation Details

- `_ChallengeSpaceBody` already had access to `status` field from `challengeDetailProvider`
- The condition `matchingDay.allCompleted` only checked if all members verified that day, not if the challenge itself was completed
- Adding `&& status == 'completed'` ensures the completion screen is only accessible for ended challenges
- For active challenges, the tap falls through to the daily verifications screen (`/challenges/{id}/verifications/{date}`)

## Tests & Build

- Analyze: pass (no issues)
- Tests: skipped (UI navigation logic, no unit test coverage)
- Build: pass (`flutter build ios --simulator`)
