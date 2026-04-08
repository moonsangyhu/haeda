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

## Cross-Layer Isolation

- Do not touch app/ code when working on server/. Vice versa.
- Local environment (Container-First): `docker compose up --build -d`. Same as `/local`.
