---
paths:
  - "app/**"
---

# App (Flutter) Rules

This file auto-loads when working in the app/ directory.

## Pre-Implementation Checklist

1. Verify screen is defined in `docs/user-flows.md`
2. Verify API response structure is defined in `docs/api-contract.md`
3. Verify P0 scope — P1 features (discover tab, notification tab, push, Apple login) are forbidden

## Code Rules

- Feature-first structure: `lib/features/{feature}/` (models/, providers/, screens/, widgets/)
- State management: Riverpod (flutter_riverpod + riverpod_annotation)
- Routing: GoRouter — challenge ID-based routes
- API client: dio + AuthInterceptor
- Response models: Follow api-contract.md data field structure exactly
- Models: freezed + json_serializable
- Season icons: Mar-May spring, Jun-Aug summer, Sep-Nov fall, Dec-Feb winter

## Forbidden

- Do not modify docs/ files
- Do not modify server/ (FastAPI) code
- Do not create screens not in user-flows.md
- Do not add bottom tab navigation (My Page is the main screen in P0)
- Do not hardcode secrets in .env
- Do not add unnecessary packages
