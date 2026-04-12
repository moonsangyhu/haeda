---
slug: your-feature-slug
status: idea          # idea | ready | in-progress | done | dropped
created: YYYY-MM-DD
area: front           # front | backend | full-stack
priority: P0          # P0 | P1 | P2
---

# {Feature title}

## 1. Problem / Why

What user pain or business need does this address? Cite the relevant `docs/prd.md` section if it maps to an existing P0/P1 item. If this is outside current scope, say so explicitly.

## 2. User-facing Behavior

Short narrative of what the user sees and does. Reference `docs/user-flows.md` screens by name. For backend-only work, describe the API consumer's perspective.

- Entry point(s):
- Main flow:
- Edge cases:
- Success state:
- Failure state:

## 3. Scope

**In scope**
- …

**Out of scope**
- …

**Deferred (P1+)**
- …

## 4. Affected Files (best-effort, read-only guesses)

| Layer | Path | Change |
|-------|------|--------|
| front | `app/lib/features/.../...dart` | … |
| backend | `server/app/routers/....py` | … |
| backend | `server/app/models/....py` | … |

Affected files are a hint for the builder; final list is decided during implementation.

## 5. API Contract / Domain Model Deltas

If this feature adds or changes any endpoint, field, or entity, list it here and cite the section in `docs/api-contract.md` / `docs/domain-model.md` that will need updating. **Do not edit those files from the planner worktree** — they are source-of-truth and require explicit user approval. Flag the needed change so `spec-keeper` can gate it during feature-flow.

- Endpoints (new/changed):
- Fields (new/changed):
- Error codes:
- Domain rules:

## 6. Acceptance Criteria (testable)

- [ ] …
- [ ] …
- [ ] …

Each criterion must map to a concrete test (unit, integration, or manual smoke) that `qa-reviewer` can run.

## 7. Open Questions

- …

Questions that need user input before implementation begins. These are gates.

## 8. Handoff Notes

- Primary builder: `backend-builder` | `flutter-builder` | both (parallel)
- Recommended worktree: `.claude/worktrees/feature` (or a dedicated slice worktree)
- Pre-reads: list any impl-log entries or prior specs the builder should skim first
- Risks: anything the debugger/QA should watch for
