# Vertical Slice Workflow

## 10-Step Flow

1. **Plan**: Enter Plan Mode (Shift+Tab), run `/slice-planning {slice-name}`. 사용자 요청이 러프하면 `brainstorming` 스킬 선행. Do not implement until approved.
2. **Spec verification (pre-impl)**: Use `spec-keeper` agent. Block if P0 scope, entities, or error codes don't match.
3. **Implementation (TDD 의무)**: `backend-builder` / `flutter-builder`. 모든 production 코드 변경은 `.claude/skills/tdd/SKILL.md` 의 RED → GREEN → REFACTOR 사이클. completion output 에 `### TDD Cycle Evidence` + `### Verification` 필수.
4. **Spec Compliance Review (post-impl)**: `spec-compliance-reviewer` 에이전트. 구현 diff 가 Step 1 Feature Plan 의 acceptance criteria / endpoint / screen / field 와 일치하는지 검증. Missing/Drift 있으면 해당 builder 재호출 (max 1 retry).
5. **Code review**: `code-reviewer` 에이전트. 품질 (스타일, 중복, 보안, TDD 증거) 검토.
6. **QA**: `qa-reviewer` 에이전트. `verification-before-completion` 스킬 준수, 모든 pass 주장에 명령+출력 인용.
7. **Debug loop (조건부)**: QA verdict = partial/incomplete 면 `debugger` 가 `.claude/skills/systematic-debugging/SKILL.md` 프로토콜로 근본 원인 조사 + fix → builder 재호출 → re-QA (max 2 retries).
8. **Deploy**: `deployer` 에이전트. Docker rebuild + iOS simulator run + `/health` check. 모든 주장 명령+출력 인용.
9. **Document (+ retrospective)**: `doc-writer` 에이전트. impl-log + test-reports + docs/reports 3개 파일. `docs/reports/` 말미에 Retrospective 섹션 3개 (What worked / What could improve / Process signal) 필수.
10. **Commit & PR**: Main 이 `/commit` 스킬 실행 → PR 생성 + 자동 머지.

## Verification Principles

- **"Prove it works."** Every slice is judged complete by actual test execution results.
- Mock success, fallback path success, or build-only pass is NOT "proof of working".
- Must cite passed/failed counts from pytest/flutter test output.
- Distinguish between actually verified and unverified items.
- Do not declare slice complete without smoke test.
- **`verification-before-completion` 스킬 준수**: 모든 agent 의 "완료/pass/성공" 주장은 명령+출력 발췌 인용. 금지 어휘 ("아마", "should work", "probably") 사용 시 verdict 무효. 자세한 건 `.claude/rules/verification.md`.
- **TDD 증거**: 모든 production 코드 변경에 RED + GREEN 로그 인용. 자세한 건 `.claude/rules/tdd.md`.

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
