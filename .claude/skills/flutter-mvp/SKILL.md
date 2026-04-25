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

## Test Requirements (MANDATORY)

기능을 구현하는 모든 PR 은 대응 테스트 없이 완료로 간주하지 않는다.

- **스크린**: 신규 스크린마다 `app/test/features/{feature}/screens/` 아래에 widget 테스트 **최소 1건** — 기본 렌더링 + 주요 상호작용 (버튼 탭, 폼 제출, 텍스트 입력 등) 검증.
- **Provider**: API 호출 / 비즈니스 로직 providers 는 `ProviderContainer` 기반 unit 테스트. 외부 `dio` 는 `mocktail` 로 대체한다.
- **Widget helpers**: `lib/core/widgets/` 에 추가하는 공용 위젯은 render 테스트 최소 1건.
- **검증 기준**: `cd app && flutter analyze` 에러 0 + `cd app && flutter test` 전원 통과. 신규 위젯 경로가 한 번도 실행되지 않으면 통과로 인정하지 않는다.

테스트는 `superpowers:test-driven-development` 사이클로 작성하고, `superpowers:verification-before-completion` 으로 결과를 인용해 보고한다.
