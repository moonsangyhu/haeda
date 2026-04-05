"""Prompt generation for each automation phase.

Token-saving design:
- Prompts tell Claude to READ file paths, not embed content.
- Each prompt is minimal: goal + file references + rules + verification.
- Prompts are saved as .md files and referenced by path in state.
"""

from __future__ import annotations

from pathlib import Path
from typing import Optional


def generate_plan_prompt(
    slice_name: str,
    *,
    prev_report_path: Optional[str] = None,
) -> str:
    """Prompt for the PLAN phase: determine next slice scope.

    Token-saving: reads only latest test report (not all), skips domain-model.md
    (entities are derivable from prd.md + api-contract.md).
    """
    report_instruction = ""
    if prev_report_path:
        report_instruction = f"4. {prev_report_path} — previous slice result (what's already done)"
    else:
        report_instruction = "4. (no previous slice report found — this may be the first slice)"

    return f"""You are the planning agent for Haeda slice automation.

## Task
Pick the next unimplemented P0 feature and define {slice_name} scope.

## Read These Files (in order, stop after each)
1. docs/prd.md — P0 feature list (§3 기능 목록)
2. docs/api-contract.md — P0 endpoints
3. docs/user-flows.md — P0 screen flows
{report_instruction}

Do NOT read CLAUDE.md, docs/domain-model.md, or scan test-reports/ directory.
Do NOT explore the codebase broadly. Focus only on the 3-4 files above.

## Decision Process
1. From prd.md, list all P0 features
2. From the previous test report, identify which P0 features are already done
3. Pick the next unimplemented P0 feature
4. From api-contract.md, extract its endpoints
5. From user-flows.md, extract its screens

## Output
Output ONLY a JSON object (no markdown fences):
{{
  "slice_name": "{slice_name}",
  "goal": "one-line goal",
  "p0_reference": "prd.md section",
  "endpoints": ["METHOD /path — description", ...],
  "screens": ["screen name — flow reference", ...],
  "entities": ["entity — fields summary", ...],
  "excluded": ["what NOT to implement"],
  "depends_on": ["prerequisite slices or empty"],
  "all_p0_complete": false
}}

If ALL P0 features are already implemented, set "all_p0_complete": true and leave other fields minimal.
"""


def generate_plan_from_artifact_prompt(
    slice_name: str,
    artifact_path: str,
) -> str:
    """Short prompt when a next-slice artifact already exists.

    Just validates the artifact and outputs the plan JSON — no broad doc reading.
    """
    return f"""A previous automation run already recommended the next slice scope.

## Read This File
1. {artifact_path} — next-slice recommendation from previous run

## Task
Validate and output the plan for {slice_name} based on the artifact above.
If the artifact looks reasonable, convert it to the output format below.
If it references features that seem already implemented, read docs/prd.md to verify,
then either confirm or pick a different P0 feature.

## Output
Output ONLY a JSON object (no markdown fences):
{{
  "slice_name": "{slice_name}",
  "goal": "one-line goal",
  "p0_reference": "prd.md section",
  "endpoints": ["METHOD /path — description", ...],
  "screens": ["screen name — flow reference", ...],
  "entities": ["entity — fields summary", ...],
  "excluded": ["what NOT to implement"],
  "depends_on": ["prerequisite slices or empty"],
  "all_p0_complete": false
}}
"""


def generate_plan_continuation_prompt(slice_name: str) -> str:
    """Short continuation prompt when plan phase hits max turns.

    Session already has all the context — just needs to output the JSON.
    """
    return f"""You ran out of turns while planning {slice_name}.

You already read the relevant docs. Do NOT re-read any files.
Just output the plan JSON now based on what you already know.

Output ONLY a JSON object (no markdown fences):
{{
  "slice_name": "{slice_name}",
  "goal": "one-line goal",
  "p0_reference": "prd.md section",
  "endpoints": ["METHOD /path — description", ...],
  "screens": ["screen name — flow reference", ...],
  "entities": ["entity — fields summary", ...],
  "excluded": ["what NOT to implement"],
  "depends_on": ["prerequisite slices or empty"],
  "all_p0_complete": false
}}
"""


def generate_backend_prompt(
    slice_name: str,
    goal: str,
    endpoints: list[str],
    entities: list[str],
) -> str:
    """Prompt for backend implementation."""
    ep_list = "\n".join(f"  {i+1}. {ep}" for i, ep in enumerate(endpoints))
    ent_list = "\n".join(f"  - {e}" for e in entities) if entities else "  (see domain-model.md)"

    return f"""## {slice_name} Backend Implementation

### Read First
- CLAUDE.md — project rules
- docs/api-contract.md — endpoint specs (request/response/errors)
- docs/domain-model.md — entity definitions and business rules

### Goal
{goal}

### Endpoints to Implement
{ep_list}

### Related Entities
{ent_list}

### Rules
- Only modify files under server/. NEVER touch app/.
- Follow .claude/skills/fastapi-mvp/ conventions.
- Response envelope: {{"data": ...}} or {{"error": {{"code": "...", "message": "..."}}}}
- Create Alembic migrations for new tables/columns.
- Write pytest tests for all new endpoints.

### Verification
Run these and ensure all pass:
1. cd server && uv run pytest -v --tb=short
2. Verify no import errors

### When Done
Create a git commit with a descriptive message for the backend changes.
Do NOT run git push.
"""


def generate_frontend_prompt(
    slice_name: str,
    goal: str,
    screens: list[str],
    endpoints: list[str],
) -> str:
    """Prompt for frontend implementation."""
    scr_list = "\n".join(f"  {i+1}. {s}" for i, s in enumerate(screens))
    ep_list = "\n".join(f"  - {ep}" for ep in endpoints)

    return f"""## {slice_name} Frontend Implementation

### Read First
- CLAUDE.md — project rules
- docs/user-flows.md — screen flows and UI structure
- docs/api-contract.md — endpoint request/response specs

### Goal
{goal}

### Screens to Implement
{scr_list}

### API Endpoints to Consume
{ep_list}

### Rules
- Only modify files under app/. NEVER touch server/.
- Follow .claude/skills/flutter-mvp/ conventions.
- Feature-first directory structure under lib/features/.
- Use Riverpod for state, GoRouter for routing, dio for HTTP.
- Use freezed + json_serializable for DTOs.
- Season icons: 3-5=spring, 6-8=summer, 9-11=fall, 12-2=winter.

### Verification
Run these and ensure all pass:
1. cd app && flutter test
2. Verify no analysis errors: cd app && flutter analyze

### When Done
Create a git commit with a descriptive message for the frontend changes.
Do NOT run git push.
"""


def generate_qa_prompt(
    slice_name: str,
    goal: str,
    endpoints: list[str],
    screens: list[str],
) -> str:
    """Prompt for QA review."""
    ep_list = "\n".join(f"  - {ep}" for ep in endpoints)
    scr_list = "\n".join(f"  - {s}" for s in screens)

    return f"""## {slice_name} QA Review

### Goal
Review the implementation of: {goal}

### Scope
Endpoints:
{ep_list}

Screens:
{scr_list}

### Review Steps
1. Read docs/api-contract.md and verify all endpoints match spec
2. Read docs/domain-model.md and verify entities/rules match
3. Read docs/user-flows.md and verify screens match
4. Run: cd server && uv run pytest -v --tb=short
5. Run: cd app && flutter test
6. Check for security issues (no hardcoded secrets, no SQL injection)
7. Check P0 scope — no P1 features or undocumented additions

### Output
Output ONLY a JSON object (no markdown fences):
{{
  "verdict": "complete" or "partial" or "incomplete",
  "tests_backend": "N passed, M failed",
  "tests_frontend": "N passed, M failed",
  "passed_items": ["item1", "item2"],
  "blocking_issues": [
    {{"area": "backend|frontend", "file": "path", "issue": "description", "doc_ref": "docs/..."}}
  ],
  "non_blocking_issues": [
    {{"area": "backend|frontend", "file": "path", "issue": "description"}}
  ]
}}
"""


def generate_remediate_prompt(
    slice_name: str,
    role: str,
    issues: list[dict],
) -> str:
    """Prompt for remediation (backend or frontend)."""
    issue_list = "\n".join(
        f"  {i+1}. [{iss.get('area', role)}] {iss.get('file', '?')}: {iss.get('issue', '?')} (ref: {iss.get('doc_ref', 'n/a')})"
        for i, iss in enumerate(issues)
    )

    scope_dir = "server" if role == "backend" else "app"
    other_dir = "app" if role == "backend" else "server"
    test_cmd = "cd server && uv run pytest -v --tb=short" if role == "backend" else "cd app && flutter test"

    return f"""## {slice_name} {role.title()} Remediation

### Read First
- CLAUDE.md — project rules
- docs/api-contract.md
- docs/domain-model.md
- docs/user-flows.md

### Issues to Fix
{issue_list}

### Rules
- Only modify files under {scope_dir}/. NEVER touch {other_dir}/.
- Fix ONLY the listed issues. Do not refactor or add features.

### Verification
Run: {test_cmd}

### When Done
Create a git commit with message: "fix({role}): {slice_name} remediation"
Do NOT run git push.
"""


def generate_re_review_prompt(
    slice_name: str,
    original_issues: list[dict],
) -> str:
    """Prompt for QA re-review after remediation."""
    issue_summary = "\n".join(
        f"  - [{iss.get('area', '?')}] {iss.get('issue', '?')}"
        for iss in original_issues
    )

    return f"""## {slice_name} QA Re-Review

### Context
Previous review found these blocking issues that were remediated:
{issue_summary}

### Review Steps
1. Verify each issue above is resolved
2. Run: cd server && uv run pytest -v --tb=short
3. Run: cd app && flutter test
4. Check no regressions introduced

### Output
Output ONLY a JSON object (no markdown fences):
{{
  "verdict": "complete" or "partial" or "incomplete",
  "tests_backend": "N passed, M failed",
  "tests_frontend": "N passed, M failed",
  "resolved_issues": ["issue description", ...],
  "remaining_issues": [
    {{"area": "backend|frontend", "file": "path", "issue": "description", "doc_ref": "docs/..."}}
  ]
}}
"""


def generate_verify_prompt(slice_name: str) -> str:
    """Prompt for post-QA local stack verification.

    Runs docker compose, smoke tests, and generates test-report.
    """
    return f"""## {slice_name} Post-QA Local Verification

### Task
Verify the full stack works locally after QA approval.

### Steps (execute in order)

1. **Start local stack**
   ```bash
   docker compose down 2>/dev/null; docker compose up --build -d
   ```
   Wait for all services to be healthy:
   ```bash
   docker compose ps
   ```
   All 3 services (db, backend, frontend) must show "healthy" or "Up".

2. **Backend health check**
   ```bash
   curl -sf http://localhost:8000/health
   ```

3. **Backend tests**
   ```bash
   cd server && uv run pytest -v --tb=short
   ```

4. **Frontend tests**
   ```bash
   cd app && flutter test
   ```

5. **Generate test report**
   Write a test report to `test-reports/{slice_name}-test-report.md` with:
   - Slice name and date
   - Backend test results (passed/failed counts)
   - Frontend test results (passed/failed counts)
   - Local stack status (services healthy)
   - Verdict: complete / partial / incomplete

### Output
Output ONLY a JSON object (no markdown fences):
{{{{
  "stack_healthy": true or false,
  "backend_health": true or false,
  "tests_backend": "N passed, M failed",
  "tests_frontend": "N passed, M failed",
  "test_report_written": true or false,
  "test_report_path": "test-reports/{slice_name}-test-report.md",
  "smoke_passed": true or false,
  "verdict": "passed" or "failed",
  "failure_reason": null or "description"
}}}}
"""


def generate_continuation_prompt(
    slice_name: str,
    role: str,
) -> str:
    """Short continuation prompt after max-turns hit.

    Minimal context — the session already has full history.
    """
    scope_dir = "server" if role == "backend" else "app"
    other_dir = "app" if role == "backend" else "server"
    test_cmd = "cd server && uv run pytest -v --tb=short" if role == "backend" else "cd app && flutter test"

    return f"""Continue implementing {slice_name} {role}. You ran out of turns.

Your previous changes are preserved. Do NOT start over.

Steps:
1. Run `git status` to see what you already changed
2. Complete any remaining work (endpoints, tests, screens)
3. Only modify {scope_dir}/. NEVER touch {other_dir}/.
4. Run: {test_cmd}
5. Commit when done.

Do NOT re-read docs you already read. Do NOT explore outside {slice_name} scope.
"""


def save_prompt(content: str, path: Path) -> None:
    """Save a prompt to file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)
