# Vertical Slice Workflow

## 9-Step Flow

1. **Plan**: Enter Plan Mode (Shift+Tab), run `/slice-planning {slice-name}`. Do not implement until approved.
2. **Spec verification**: Use `spec-keeper` agent. Block if P0 scope, entities, or error codes don't match.
3. **Implementation**: `backend-builder` -> `flutter-builder`. Or directly as needed.
4. **Check**: `/mvp-slice-check {slice-name}` + `/docs-drift-check`
5. **Review**: `qa-reviewer` agent
6. **Remediation loop**: If verdict is "partial"/"incomplete", paste remediation prompt -> fix -> re-review. Use `/qa-remediation` if needed.
7. **Integration check**: `/smoke-test` for full stack verification
8. **Record results**: `/slice-test-report {slice-name}` -> save to `test-reports/`
9. **Next slice**: Paste QA next-slice prompts, or `/next-slice-planning`

## Verification Principles

- **"Prove it works."** Every slice is judged complete by actual test execution results.
- Mock success, fallback path success, or build-only pass is NOT "proof of working".
- Must cite passed/failed counts from pytest/flutter test output.
- Distinguish between actually verified and unverified items.
- Do not declare slice complete without smoke test.

## Mandatory Local Build & Deploy

Every feature/fix that changes source code (app/ or server/) MUST end with a local container rebuild and health check. This is **non-negotiable** — no feature is complete without it.

| Changed Area | Required Command | Health Check |
|-------------|-----------------|--------------|
| server/ only | `docker compose up --build -d backend` | `curl -s http://localhost:8000/health` |
| app/ only | `cd app && flutter run -d <simulator-device-id>` | 시뮬레이터에서 앱 실행 확인 |
| Both | `docker compose up --build -d backend` + `cd app && flutter run -d <simulator-device-id>` | Backend health + 시뮬레이터 실행 |

**Flutter 검증은 반드시 iOS simulator에서 앱을 실행하여 확인한다.**
- `flutter build ios --simulator`(빌드만)는 검증으로 인정하지 않는다.
- `flutter build web`은 검증으로 인정하지 않는다.
- 시뮬레이터에서 앱이 실행되어 화면을 확인할 수 있는 상태까지가 검증 완료.

**Rules:**
- Run AFTER commit/push, BEFORE declaring work complete
- If health check fails, fix and rebuild — do NOT skip
- Config-only changes (.claude/, docs/) are exempt
- This applies to all workflows: slice, fix, refine, manual feature work

## Task Report (Mandatory for every state-changing task)

`.claude/rules/worktree-task-report.md` 에 정의된 대로, 모든 상태 변경 작업(feature, fix, config, rebase 포함)은 `docs/reports/YYYY-MM-DD-{role}-{slug}.md` 보고서를 git 에 남긴 뒤 커밋한다. 보고서 없이 `/commit` 을 실행하지 않는다.

## Cross-Layer Isolation

- Do not touch app/ code when working on server/. Vice versa.
- Local environment (Container-First): `docker compose up --build -d`. Same as `/local`.
