"""Prompt generation for refinement pipeline.

Token-saving design (same as prompts.py):
- Prompts tell Claude to READ file paths, not embed content.
- Each prompt is minimal: goal + file references + rules + verification.
"""

from __future__ import annotations

from typing import Optional


def generate_analyze_prompt(
    request_text: str,
    *,
    user_criteria: Optional[list[str]] = None,
    user_out_of_scope: Optional[list[str]] = None,
) -> str:
    """Prompt for ANALYZE phase: parse request, determine scope, find files."""
    constraints_block = ""
    if user_criteria or user_out_of_scope:
        parts = []
        if user_criteria:
            parts.append("Acceptance criteria (user-provided, include in output):")
            parts.extend(f"  - {c}" for c in user_criteria)
        if user_out_of_scope:
            parts.append("Out of scope (user-provided):")
            parts.extend(f"  - {s}" for s in user_out_of_scope)
        constraints_block = "\n### User Constraints\n" + "\n".join(parts)

    return f"""## Refinement Request Analysis

### Read First (skim only relevant sections)
- docs/user-flows.md — screen structure
- docs/api-contract.md — endpoint specs

### User Request
{request_text}
{constraints_block}

### Task
Analyze this refinement request:
1. Determine affected area (frontend / backend / both)
2. Search the codebase to find relevant files (use Glob and Grep)
3. Determine acceptance criteria (use user-provided if given, add more if needed)
4. Identify what is out of scope

Do NOT make any changes. Analysis only.
Do NOT read CLAUDE.md or domain-model.md unless the request clearly involves domain logic.

### Output
Output ONLY a JSON object (no markdown fences):
{{
  "summary": "one-line description of the change",
  "affected_area": "frontend" or "backend" or "both",
  "acceptance_criteria": ["criterion 1", "criterion 2"],
  "out_of_scope": ["exclusion 1"],
  "backend_changes": null or {{
    "description": "what to change",
    "files": ["server/app/path/to/file.py"],
    "approach": "how to change it"
  }},
  "frontend_changes": null or {{
    "description": "what to change",
    "files": ["app/lib/path/to/file.dart"],
    "approach": "how to change it"
  }}
}}
"""


def generate_implement_prompt(
    area: str,
    summary: str,
    changes: dict,
    acceptance_criteria: list[str],
) -> str:
    """Prompt for IMPLEMENT phase: make code changes for one area."""
    scope_dir = "server" if area == "backend" else "app"
    other_dir = "app" if area == "backend" else "server"
    test_cmd = (
        "cd server && uv run pytest -v --tb=short"
        if area == "backend"
        else "cd app && flutter test"
    )

    files_list = "\n".join(f"  - {f}" for f in changes.get("files", []))
    criteria_list = "\n".join(f"  - {c}" for c in acceptance_criteria)

    return f"""## Refinement: {summary}

### Changes Required
{changes.get("description", "See files below")}

### Approach
{changes.get("approach", "Make the necessary changes")}

### Files to Modify
{files_list}

### Acceptance Criteria
{criteria_list}

### Rules
- Only modify files under {scope_dir}/. NEVER touch {other_dir}/ or docs/.
- Make minimal, focused changes. Do not refactor surrounding code.
- Do not add features beyond what was requested.
- Do not add docstrings or comments to code you didn't change.

### Verification
Run after changes: {test_cmd}
Ensure all tests pass. Fix any test failures before finishing.

### Important
- Do NOT run git commit or git push.
- Do NOT modify any files in docs/.
"""


def generate_remediate_prompt(
    area: str,
    summary: str,
    changes: dict,
    acceptance_criteria: list[str],
    failure_reason: str,
) -> str:
    """Prompt for remediation after verify failure."""
    scope_dir = "server" if area == "backend" else "app"
    other_dir = "app" if area == "backend" else "server"
    test_cmd = (
        "cd server && uv run pytest -v --tb=short"
        if area == "backend"
        else "cd app && flutter test"
    )

    files_list = "\n".join(f"  - {f}" for f in changes.get("files", []))
    criteria_list = "\n".join(f"  - {c}" for c in acceptance_criteria)

    return f"""## Refinement Fix: {summary}

### Previous Attempt Failed
Reason: {failure_reason}

### What Was Supposed to Change
{changes.get("description", "See files below")}

### Files Already Modified
{files_list}

### Acceptance Criteria (must all pass)
{criteria_list}

### Rules
- Only modify files under {scope_dir}/. NEVER touch {other_dir}/ or docs/.
- Run `git diff` first to see what was already changed.
- Fix the failure. Do not start over.

### Verification
Run: {test_cmd}

### Important
- Do NOT run git commit or git push.
"""


def generate_verify_prompt(
    summary: str,
    affected_area: str,
    acceptance_criteria: list[str],
) -> str:
    """Prompt for VERIFY phase: tests + docker rebuild + acceptance check."""
    criteria_list = "\n".join(
        f"  {i + 1}. {c}" for i, c in enumerate(acceptance_criteria)
    )

    test_steps = []
    if affected_area in ("backend", "both"):
        test_steps.append("cd server && uv run pytest -v --tb=short")
    if affected_area in ("frontend", "both"):
        test_steps.append("cd app && flutter test")
    test_block = "\n".join(f"   ```bash\n   {s}\n   ```" for s in test_steps)

    return f"""## Refinement Verification: {summary}

### Step 1: Run Tests
{test_block}

### Step 2: Rebuild Local Stack
```bash
docker compose down 2>/dev/null; docker compose up --build -d
```
Wait for healthy:
```bash
sleep 5 && docker compose ps
```

### Step 3: Health Check
```bash
curl -sf http://localhost:8000/health
```

### Step 4: Acceptance Criteria
Review the changed files and verify each criterion:
{criteria_list}

### Output
Output ONLY a JSON object (no markdown fences):
{{{{
  "tests_backend": "N passed, M failed" or "skipped",
  "tests_frontend": "N passed, M failed" or "skipped",
  "stack_healthy": true or false,
  "health_check": true or false,
  "criteria_results": [
    {{{{"criterion": "...", "met": true or false, "evidence": "brief explanation"}}}}
  ],
  "verdict": "passed" or "failed",
  "failure_reason": null or "description"
}}}}
"""
