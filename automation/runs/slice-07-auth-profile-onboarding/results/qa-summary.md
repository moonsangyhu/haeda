# QA Result — slice-07-auth-profile-onboarding

Verdict: **complete**
Backend tests: 74 passed, 0 failed
Frontend tests: 87 passed, 0 failed

```json
{
  "verdict": "complete",
  "tests_backend": "74 passed, 0 failed",
  "tests_frontend": "87 passed, 0 failed",
  "passed_items": [
    "build_runner generated auth_provider.g.dart and all .g.dart/.freezed.dart files successfully (29 outputs)",
    "POST /auth/kakao — new user and existing user flows pass, invalid token returns 401",
    "PATCH /auth/profile — nickname validation (min 1, max N), no-auth 401, boundary cases all pass",
    "Kakao OAuth login screen (KakaoOauthScreen) navigable from LoginScreen",
    "ProfileSetupScreen — AppBar title, nickname TextField, validation errors, profile image CircleAvatar all pass",
    "LoginScreen — app name display and Kakao login button navigation to /kakao-oauth pass",
    "Challenge create flow (Step1, Step2, Complete screens) — field presence, validation, navigation all pass",
    "Challenge join flow (InvitePreviewScreen) — title, category, join button all pass",
    "Challenge completion screen — title rendering, 내 페이지로 button navigation to / pass",
    "MyPageScreen — active/completed challenge separation renders correctly",
    "Verification detail screen — AppBar title, comment TextField, list item onTap all pass",
    "Create verification screen — AppBar title passes",
    "Achievement rate calculation — daily full/partial/zero, weekly full/partial all pass",
    "Season determination — spring (3-5), summer (6-8), fall (9-11), winter (12-2) all pass",
    "Scheduler — daily/weekly close, already-completed guard, future/ongoing exclusion, expected-days calculation all pass",
    "Scheduler registration — job registered, trigger is daily midnight",
    "GET /challenges/{id} — success, not-member 403, not-found 404",
    "GET /challenges/{id}/calendar — success, not-member, not-found, empty month all pass",
    "POST /challenges/{id}/verifications — success, duplicate, photo-required, not-member, day-completion trigger all pass",
    "GET /challenges/{id}/verifications — success, empty, not-member all pass",
    "GET /verifications/{id} — success, not-found, not-member",
    "GET /verifications/{id}/comments, POST /verifications/{id}/comments — happy path, too-long, not-member, not-found all pass",
    "POST /challenges — happy path, invalid date range, invalid frequency, weekly missing times all pass",
    "GET /invites/{code} — happy path, not-member, invalid code all pass",
    "POST /challenges/{id}/join — happy path, already-joined, not-found, ended all pass",
    "GET /me/challenges — list, status filter, achievement rate, empty, no-token all pass",
    "GET /challenges/{id}/completion — happy path, not-found, not-member, not-completed all pass",
    "No hardcoded secrets or credentials found in committed code",
    "server/ and app/ directory scopes maintained throughout implementation"
  ],
  "blocking_issues": [],
  "non_blocking_issues": [
    {
      "area": "frontend",
      "file": "app/pubspec.yaml or analyzer",
      "issue": "SDK language version 3.11.0 is newer than analyzer language version 3.9.0 — run flutter packages upgrade to align analyzer version. Does not block tests but may cause false negatives in static analysis."
    }
  ]
}
```
