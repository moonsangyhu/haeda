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
| `flutter-builder` | `cd app && flutter build ios --simulator` |
| `backend-builder` | `cd server && docker compose build` or `python -m py_compile` |

- **flutter-builder는 반드시 iOS simulator 빌드**를 사용한다. `flutter build web`은 검증으로 인정하지 않는다.
- If build fails, the agent must fix the error and rebuild before reporting completion.
- Do NOT report "implementation complete" without a passing build.

**Main(Opus)은 flutter-builder 완료 후, 반드시 시뮬레이터에서 앱을 실행(`flutter run -d <device-id>`)하여 화면을 확인해야 한다.** 빌드 성공만으로 검증 완료가 아님. 시뮬레이터에서 앱이 떠서 화면을 볼 수 있어야 검증 완료.

## Post-Implementation (Mandatory)

After builder agent completes with passing build, Main (Opus) MUST run `/commit` to:
1. Stage & commit changes
2. Push directly to main (no branches, no PRs)
3. Write implementation log to `impl-log/<name>.md`

Do NOT stop after "build success" — the cycle is: **implement → build → commit → push to main → simulator 실행 확인 → impl-log**.

## Implementation Log (`impl-log/`)

Every feature/fix gets a detailed log file at `impl-log/<branch-name>.md`.
- Created automatically by `/commit` skill
- Referenced by `/rollback` skill to know what to undo
- Agents MUST read relevant impl-logs before modifying previously implemented features
