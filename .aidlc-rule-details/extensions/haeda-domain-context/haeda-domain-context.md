# Haeda Domain Context Extension (ALWAYS-ENFORCED)

## Overview

Haeda has project-specific terminology, visual language, and API contract conventions that every AIDLC stage MUST respect. This extension fixes those conventions so Inception and Construction artifacts stay consistent.

**Enforcement**: Applied at **Inception → Requirements Analysis**, **Inception → Application Design**, and **Construction → Functional Design** / **Code Generation**. Violations are blocking findings — the relevant stage MUST NOT complete until corrected.

## Rule DOMAIN-01: Terminology (English in code, Korean in UX)

**Rule**: Code identifiers (class names, function names, table names, API paths, variable names) MUST use the English domain terms below. User-facing copy (screens, notifications, error messages shown to end-users) MUST use the Korean equivalents.

| Concept | Code identifier | Korean UX term |
|---------|-----------------|----------------|
| Challenge (a collective activity tracked on the calendar) | `Challenge` | 챌린지 |
| Verification (a single submission / proof event) | `Verification` | 인증 |
| DayCompletion (one day marked done for a given challenge) | `DayCompletion` | 하루 완료 |
| ChallengeMember (a user's membership in a challenge) | `ChallengeMember` | 챌린지 참여자 |
| Comment (reaction on a verification) | `Comment` | 댓글 |
| User (account) | `User` | 사용자 |
| Character (avatar persona) | `Character` | 캐릭터 |

**Verification**:
- No code identifier uses Korean characters or Romanized mixed-script variants (e.g., `ChalengeGi`, `Injeung`)
- No user-facing string uses raw English domain terms where a Korean equivalent exists (microcopy like "OK" button is fine)
- Requirements, stories, and design artifacts reference the English identifiers in technical sections and Korean in user-journey descriptions

## Rule DOMAIN-02: API response envelope

**Rule**: All REST endpoints use the response envelope below.

Success response:
```json
{"data": <payload>}
```

Error response:
```json
{"error": {"code": "<UPPER_SNAKE_CASE>", "message": "<human-readable>"}}
```

**Verification**:
- No endpoint returns a bare object or array at the top level
- Error code values are `UPPER_SNAKE_CASE` and are documented in the requirements / application-design artifact for that feature
- HTTP status code aligns with the envelope (e.g., `400` + `{"error": {"code": "VALIDATION_FAILED", ...}}`)

## Rule DOMAIN-03: Error code registry

Every new error code introduced by a unit MUST be added to a registry in `aidlc-docs/inception/application-design/error-codes.md` (created on first use). Each entry lists:
- Code (`UPPER_SNAKE_CASE`)
- HTTP status
- Where it's raised (module + function)
- User-facing message (Korean)

**Verification**:
- Any `raise HTTPException(detail={"error": {"code": ...}})` or equivalent in new code has a matching row in the registry
- No duplicate codes across endpoints with different meanings

## Rule DOMAIN-04: Season icons

**Rule**: Season classification for calendar UI uses calendar-month ranges:

| Season | Months | Korean |
|--------|--------|--------|
| Spring | March, April, May | 봄 |
| Summer | June, July, August | 여름 |
| Fall | September, October, November | 가을 |
| Winter | December, January, February | 겨울 |

**Verification**:
- Any season-derivation function (Flutter or FastAPI) maps months exactly per the table above
- No ambiguous "late spring / early summer" blending — the boundary is month start
- Season identifiers in code use English (`spring`, `summer`, `fall`, `winter`)

## Rule DOMAIN-05: File and function size guardrails

**Rule**: Generated code respects these limits (same values as pre-migration `coding-style.md`).

| Metric | Recommended | Maximum |
|--------|-------------|---------|
| Lines per file | 200-400 | 800 |
| Lines per function | 10-30 | 50 |
| Nesting depth | 2-3 | 4 |
| Parameters per function | 3-4 | 6 |

**Verification**:
- Code generation does not produce single files over 800 lines
- Functions exceeding 50 lines are flagged in the stage summary with a rationale or a follow-up refactor task
- Function names containing `and` are flagged for potential split

## Rule DOMAIN-06: MVP scope guardrail

**Rule**: Haeda is a 4-week hospital pilot MVP. Only P0 features (as recorded in the current `aidlc-docs/inception/requirements/requirements.md`) may be implemented without an explicit user opt-in. P1+ features MUST be confirmed with the user at Requirements Analysis before they flow into Construction.

**Verification**:
- Each user story has a P0 / P1 / P2 tag
- The workflow-planning artifact excludes P1+ units by default
- If a unit implements P1+, the audit.md shows an explicit user approval for that scope extension

## Interaction with AIDLC Stages

- **Requirements Analysis**: use the terminology table for entity naming; reject Korean-only technical terms in functional requirements
- **User Stories**: acceptance criteria reference English identifiers in technical parts, Korean in user-visible parts
- **Application Design**: all component / service names follow DOMAIN-01; API envelopes follow DOMAIN-02
- **Functional Design**: new error codes added to the registry per DOMAIN-03
- **Code Generation**: all 6 rules apply; compliance block required in stage summary
- **Build and Test**: N/A unless a test specifically exercises envelope / error-code format

## Compliance Summary Format

```
## Extension Compliance — haeda-domain-context
- DOMAIN-01 Terminology: compliant — English identifiers, Korean UX copy
- DOMAIN-02 API envelope: compliant — all endpoints use {"data":...} / {"error":{...}}
- DOMAIN-03 Error registry: compliant — 2 new codes added to error-codes.md
- DOMAIN-04 Season icons: N/A — no calendar code in this unit
- DOMAIN-05 Size guardrails: compliant — largest file 340 lines
- DOMAIN-06 MVP scope: compliant — unit implements only P0 requirement REQ-CH-03
```
