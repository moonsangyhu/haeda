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
- **Rollback**: When user requests rollback/undo, run `/rollback` skill.
- **Main (Opus)**: Requirements analysis, plan, agent coordination, reports/commits/rebuilds.

## Build Verification (Mandatory)

Builder agents MUST run a full build as the final step — analyze/test alone is insufficient.

| Agent | Required Build Command |
|-------|----------------------|
| `flutter-builder` | `cd app && flutter build web` |
| `backend-builder` | `cd server && docker compose build` or `python -m py_compile` |

- If build fails, the agent must fix the error and rebuild before reporting completion.
- Do NOT report "implementation complete" without a passing build.

## Post-Implementation (Mandatory)

After builder agent completes with passing build, Main (Opus) MUST run `/commit` to:
1. Stage & commit changes
2. Push to feature branch
3. Create PR with numbered title (`#NN <message>`)
4. Write implementation log to `impl-log/<branch>.md`

Do NOT stop after "build success" — the cycle is: **implement → build → commit → PR → impl-log**.

## Implementation Log (`impl-log/`)

Every feature/fix gets a detailed log file at `impl-log/<branch-name>.md`.
- Created automatically by `/commit` skill
- Referenced by `/rollback` skill to know what to undo
- Agents MUST read relevant impl-logs before modifying previously implemented features
