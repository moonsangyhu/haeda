# Agent Team

All implementation and review work uses a 4-agent team. Main (Opus) handles analysis, planning, and coordination only.

| Agent | Model | Role | Scope |
|-------|-------|------|-------|
| `backend-builder` | Sonnet | FastAPI implementation | server/ only |
| `flutter-builder` | Sonnet | Flutter UI implementation | app/ only |
| `ui-designer` | Sonnet | UI design/polish/accessibility | app/ only |
| `qa-reviewer` | Sonnet | Test execution + quality review | read-only + bash |

## Dispatch Rules

- **Implementation**: Delegate to matching builder agent. Cross-layer = run both builders in parallel.
- **Design**: UI/UX improvements go to `ui-designer` first, then `flutter-builder` integrates.
- **QA**: After implementation, `qa-reviewer` runs tests + checklist review.
- **Spec check**: Use `spec-keeper` agent to validate plans against docs before implementation.
- **Main (Opus)**: Requirements analysis, plan, agent coordination, reports/commits/rebuilds.
