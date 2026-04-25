---
paths:
  - "app/**"
---

# App (Flutter) Rules

This file auto-loads when working in the app/ directory.

## Pre-Implementation Checklist

1. Verify screen is defined in `docs/user-flows.md`
2. Verify API response structure is defined in `docs/api-contract.md`
3. Verify P0/P1 scope — features beyond P1 (Apple login, admin dashboard, etc.) are forbidden

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
- Do not add features beyond P1 scope
- Do not hardcode secrets in .env
- Do not add unnecessary packages
