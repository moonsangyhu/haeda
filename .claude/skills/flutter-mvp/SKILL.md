---
name: flutter-mvp
description: Flutter MVP implementation rules (directory structure, state management, routing, API client)
---

# Flutter MVP Rules

## Directory Structure (feature-first)

```
lib/
├── app.dart                    # MaterialApp + GoRouter config
├── core/
│   ├── api/                    # dio client, interceptors, response models
│   ├── auth/                   # token storage, Kakao OAuth
│   ├── theme/                  # colors, typography, season icon assets
│   └── widgets/                # common widgets (loading, error, empty state)
├── features/
│   ├── auth/                   # login, profile setup
│   ├── my_page/                # my challenge list
│   ├── challenge_create/       # challenge creation (Step 1~2 + complete)
│   ├── challenge_join/         # invite link join
│   ├── challenge_space/        # calendar view, daily verification status
│   ├── verification/           # verification submit, verification detail
│   ├── comment/                # comment list, comment creation
│   └── challenge_complete/     # challenge completion result
└── main.dart
```

Each feature directory structure:

```
feature/
├── models/          # response DTOs (freezed)
├── providers/       # Riverpod providers
├── screens/         # screen widgets
└── widgets/         # feature-specific widgets
```

## State Management: Riverpod

- `flutter_riverpod` + `riverpod_annotation` + `riverpod_generator`
- API calls: `FutureProvider` or `AsyncNotifierProvider`
- Form state: `StateNotifierProvider` or `NotifierProvider`
- Code generation: use `build_runner`

## Routing: GoRouter

- Challenge ID-based routes: `/challenges/:id`, `/challenges/:id/verify`
- Invite deep link: `/invite/:code`
- Auth-required routes check token in `redirect`

## API Client: dio

- Base URL: injected from environment variable (`/api/v1`)
- `AuthInterceptor`: adds `Authorization: Bearer <token>` to all requests
- Response envelope: `{ "data": ... }` -> parse only `data` field
- Error envelope: `{ "error": { "code": "...", "message": "..." } }` -> convert to exception

## Models

- `freezed` + `json_serializable` for immutable DTOs
- Field names match `api-contract.md` response fields (snake_case JSON <-> camelCase Dart)

## Screen Design Principles

- My Page is the main screen (no bottom tabs in P0)
- Challenge creation is a 2-step form
- Calendar view is monthly, swipe left/right to change month
- Verification submission: photo (camera/gallery) + diary text
