"""Phase orchestration for refinement pipeline.

Phases: analyze -> implement -> verify -> report -> commit -> push
Each phase is minimal. Report/commit/push are pure Python (no Claude).
"""

from __future__ import annotations

import json
import logging
import subprocess
from pathlib import Path

from .claude_runner import run_claude
from .config import (
    MAX_TURNS_ANALYZE,
    MAX_TURNS_IMPLEMENT,
    MAX_TURNS_VERIFY_REFINE,
    REPO_ROOT,
)
from .phases import _get_git_status, _parse_json_result, check_repo_clean  # noqa: F401
from .prompts import save_prompt
from .refine_prompts import (
    generate_analyze_prompt,
    generate_implement_prompt,
    generate_remediate_prompt,
    generate_verify_prompt,
)
from .refine_state import RefineState

log = logging.getLogger(__name__)

# Scope prefixes for scoped commit (role + test files combined)
_SCOPE_PATHS = {
    "frontend": [
        "app/lib/",
        "app/pubspec.yaml",
        "app/pubspec.lock",
        "app/test/",
    ],
    "backend": [
        "server/app/",
        "server/alembic/",
        "server/alembic.ini",
        "server/pyproject.toml",
        "server/seed.py",
        "server/tests/",
    ],
}


async def phase_analyze(
    run: RefineState,
    *,
    user_criteria: list[str] | None = None,
    user_out_of_scope: list[str] | None = None,
) -> dict:
    """ANALYZE: Parse request, determine scope, find relevant files.

    Returns analysis dict with affected_area, files, acceptance_criteria.
    """
    log.info("=== PHASE: ANALYZE ===")
    run.transition("analyze")

    rd = run._run_dir

    prompt = generate_analyze_prompt(
        run.request_text,
        user_criteria=user_criteria,
        user_out_of_scope=user_out_of_scope,
    )
    save_prompt(prompt, rd / "prompts" / "analyze.md")

    result = await run_claude(
        prompt=prompt,
        cwd=REPO_ROOT,
        log_file=rd / "logs" / "analyze.log",
        allowed_tools=["Read", "Glob", "Grep"],
        max_turns=MAX_TURNS_ANALYZE,
    )

    if result.exit_code != 0:
        run.mark_failed(f"Analysis failed: exit {result.exit_code}")
        raise RuntimeError("Analysis phase failed")

    analysis = _parse_json_result(result.result_text)

    # Save analysis artifact
    (rd / "results" / "analysis.json").write_text(
        json.dumps(analysis, indent=2, ensure_ascii=False) + "\n"
    )
    run.analysis_file = "results/analysis.json"
    run.affected_area = analysis.get("affected_area", "frontend")
    run.save()

    log.info(
        "Analysis: area=%s, summary=%s",
        analysis.get("affected_area"),
        analysis.get("summary", "")[:60],
    )
    return analysis


async def phase_implement(
    run: RefineState,
    analysis: dict,
    *,
    is_remediation: bool = False,
) -> None:
    """IMPLEMENT: Make code changes. Runs sequentially per area."""
    label = "REMEDIATE" if is_remediation else "IMPLEMENT"
    log.info("=== PHASE: %s ===", label)
    run.transition("implement")

    rd = run._run_dir
    area = analysis.get("affected_area", "frontend")
    summary = analysis.get("summary", "refinement")
    acceptance = analysis.get("acceptance_criteria", [])

    # Failure reason for remediation
    failure_reason = ""
    if is_remediation:
        verify_path = rd / "results" / "verify-summary.json"
        if verify_path.exists():
            try:
                vdata = json.loads(verify_path.read_text())
                failure_reason = vdata.get("failure_reason") or "Previous verify failed"
            except json.JSONDecodeError:
                failure_reason = "Previous verify failed"

    # Determine areas to implement
    areas = []
    if area in ("backend", "both"):
        areas.append("backend")
    if area in ("frontend", "both"):
        areas.append("frontend")

    for impl_area in areas:
        changes = analysis.get(f"{impl_area}_changes") or {}

        if is_remediation:
            prompt = generate_remediate_prompt(
                impl_area, summary, changes, acceptance, failure_reason
            )
            prompt_name = f"remediate-{impl_area}.md"
            log_name = f"remediate-{impl_area}.log"
        else:
            prompt = generate_implement_prompt(
                impl_area, summary, changes, acceptance
            )
            prompt_name = f"implement-{impl_area}.md"
            log_name = f"implement-{impl_area}.log"

        save_prompt(prompt, rd / "prompts" / prompt_name)

        result = await run_claude(
            prompt=prompt,
            cwd=REPO_ROOT,
            log_file=rd / "logs" / log_name,
            allowed_tools=["Read", "Edit", "Write", "Bash", "Glob", "Grep"],
            max_turns=MAX_TURNS_IMPLEMENT,
        )

        # Save summary
        (rd / "results" / f"implement-{impl_area}-summary.md").write_text(
            f"# {impl_area.title()} {'Remediation' if is_remediation else 'Implementation'}\n\n"
            f"Exit: {result.exit_code} | Turns: {result.num_turns or '?'}\n\n"
            f"{result.result_text[:500]}\n"
        )

        if result.exit_code != 0:
            log.warning("%s %s failed (exit %d)", impl_area, label.lower(), result.exit_code)
            run.mark_failed(f"{impl_area} {label.lower()} failed: exit {result.exit_code}")
            raise RuntimeError(f"{impl_area} {label.lower()} failed")

        log.info("%s %s done (turns: %s)", impl_area, label.lower(), result.num_turns)


async def phase_verify(run: RefineState, analysis: dict) -> dict:
    """VERIFY: Tests + docker rebuild + acceptance criteria check."""
    log.info("=== PHASE: VERIFY ===")
    run.transition("verify")

    rd = run._run_dir
    summary = analysis.get("summary", "refinement")
    area = analysis.get("affected_area", "frontend")
    acceptance = analysis.get("acceptance_criteria", [])

    prompt = generate_verify_prompt(summary, area, acceptance)
    save_prompt(prompt, rd / "prompts" / "verify.md")

    result = await run_claude(
        prompt=prompt,
        cwd=REPO_ROOT,
        log_file=rd / "logs" / "verify.log",
        allowed_tools=["Read", "Bash", "Glob", "Grep"],
        max_turns=MAX_TURNS_VERIFY_REFINE,
    )

    try:
        verify_data = _parse_json_result(result.result_text)
    except (json.JSONDecodeError, ValueError):
        verify_data = {
            "verdict": "failed",
            "failure_reason": "Could not parse verify output",
        }

    # Save verify result
    (rd / "results" / "verify-summary.json").write_text(
        json.dumps(verify_data, indent=2, ensure_ascii=False) + "\n"
    )

    run.verify_verdict = verify_data.get("verdict", "failed")
    run.tests_backend = verify_data.get("tests_backend")
    run.tests_frontend = verify_data.get("tests_frontend")
    run.save()

    log.info("Verify verdict: %s", run.verify_verdict)
    return verify_data


def phase_report(run: RefineState, analysis: dict, verify: dict) -> None:
    """REPORT: Generate refinement report (pure Python, no Claude)."""
    log.info("=== PHASE: REPORT ===")
    run.transition("report")

    rd = run._run_dir

    # Acceptance criteria results
    criteria_lines = []
    for cr in verify.get("criteria_results", []):
        status = "PASS" if cr.get("met") else "FAIL"
        criteria_lines.append(
            f"- [{status}] {cr.get('criterion', '?')}: {cr.get('evidence', '')}"
        )

    report = [
        f"# Refinement Report: {run.run_id}",
        f"",
        f"## Request",
        f"{run.request_text}",
        f"",
        f"## Analysis",
        f"- Summary: {analysis.get('summary', 'N/A')}",
        f"- Affected area: {run.affected_area}",
        f"- Retries: {run.retry_count}",
        f"",
        f"## Acceptance Criteria",
        *(criteria_lines if criteria_lines else ["- (no criteria results)"]),
        f"",
        f"## Test Results",
        f"- Backend: {run.tests_backend or 'skipped'}",
        f"- Frontend: {run.tests_frontend or 'skipped'}",
        f"- Stack healthy: {verify.get('stack_healthy', '?')}",
        f"- Verify verdict: {run.verify_verdict}",
        f"",
        f"## Commit",
        f"- Hash: {run.commit_hash or 'pending'}",
        f"- Push: {run.push_status}",
    ]

    if run.error:
        report.extend([f"", f"## Error", f"{run.error}"])

    (rd / "results" / "report.md").write_text("\n".join(report) + "\n")
    run.report_file = "results/report.md"
    run.save()


def _find_commits_since(since_iso: str) -> list[str]:
    """Find commit hashes created after the given ISO timestamp.

    Detects commits Claude made during implement phase (despite being told not to).
    """
    result = subprocess.run(
        ["git", "log", "--since", since_iso, "--format=%H", "--reverse"],
        capture_output=True,
        text=True,
        cwd=str(REPO_ROOT),
    )
    return [h.strip() for h in result.stdout.strip().split("\n") if h.strip()]


def _get_head_short() -> str:
    result = subprocess.run(
        ["git", "rev-parse", "--short", "HEAD"],
        capture_output=True,
        text=True,
        cwd=str(REPO_ROOT),
    )
    return result.stdout.strip()


def phase_commit(run: RefineState, analysis: dict) -> str | None:
    """COMMIT: Scoped git commit. Returns commit hash or None.

    Handles two cases:
    1. Normal: uncommitted changes exist → stage scoped files → commit
    2. Claude already committed: no uncommitted changes but new commits
       exist since run started → adopt the latest commit hash
    """
    log.info("=== PHASE: COMMIT ===")
    run.transition("commit")

    area = run.affected_area or "frontend"
    summary = analysis.get("summary", "refinement")

    # Find all changed files (modified + untracked + deleted)
    result = subprocess.run(
        ["git", "status", "--porcelain"],
        capture_output=True,
        text=True,
        cwd=str(REPO_ROOT),
    )
    all_changed = []
    for line in result.stdout.strip().split("\n"):
        line = line.strip()
        if not line:
            continue
        path = line[3:].split(" -> ")[-1]
        all_changed.append(path)

    # Case 1: uncommitted changes exist → stage and commit
    if all_changed:
        scope_prefixes = []
        if area in ("frontend", "both"):
            scope_prefixes.extend(_SCOPE_PATHS["frontend"])
        if area in ("backend", "both"):
            scope_prefixes.extend(_SCOPE_PATHS["backend"])

        scoped = [f for f in all_changed if any(f.startswith(p) for p in scope_prefixes)]

        if not scoped:
            log.info("No in-scope changes to commit (changed: %d, in-scope: 0)", len(all_changed))
            # Fall through to case 2 check
        else:
            for f in scoped:
                subprocess.run(["git", "add", f], cwd=str(REPO_ROOT))

            if area == "frontend":
                prefix = "refine(front)"
            elif area == "backend":
                prefix = "refine(backend)"
            else:
                prefix = "refine"

            msg = (
                f"{prefix}: {summary}\n\n"
                f"Refinement run: {run.run_id}\n\n"
                f"Co-Authored-By: Claude <noreply@anthropic.com>"
            )

            result = subprocess.run(
                ["git", "commit", "-m", msg],
                capture_output=True,
                text=True,
                cwd=str(REPO_ROOT),
            )

            if result.returncode != 0:
                err = result.stderr.strip()[:200]
                log.error("Commit failed: %s", err)
                run.error = f"Commit failed: {err}"
                run.save()
                return None

            commit_hash = _get_head_short()
            run.commit_hash = commit_hash
            run.save()
            log.info("Committed: %s (%d files)", commit_hash, len(scoped))
            return commit_hash

    # Case 2: Claude already committed during implement phase
    # Check for commits made since run started
    if run.started_at:
        new_commits = _find_commits_since(run.started_at)
        if new_commits:
            commit_hash = _get_head_short()
            run.commit_hash = commit_hash
            run.save()
            log.info(
                "Adopted existing commit(s): %s (%d commit(s) since run start)",
                commit_hash,
                len(new_commits),
            )
            return commit_hash

    log.info("No changes to commit")
    return None


def _has_unpushed_commits() -> bool:
    """Check if there are commits ahead of remote."""
    result = subprocess.run(
        ["git", "rev-list", "--count", "@{u}..HEAD"],
        capture_output=True,
        text=True,
        cwd=str(REPO_ROOT),
    )
    if result.returncode != 0:
        return True  # No upstream → needs push
    return int(result.stdout.strip()) > 0


def phase_push(run: RefineState) -> bool:
    """PUSH: Git push to remote. Only runs if auto_push=True."""
    log.info("=== PHASE: PUSH ===")
    run.transition("push")

    if not run.auto_push:
        run.push_status = "skipped"
        run.save()
        log.info("Push skipped (AUTO_PUSH=0)")
        return True

    # Skip if nothing to push
    if not _has_unpushed_commits():
        run.push_status = "skipped"
        run.save()
        log.info("Nothing to push — already up to date")
        return True

    result = subprocess.run(
        ["git", "push"],
        capture_output=True,
        text=True,
        cwd=str(REPO_ROOT),
    )

    if result.returncode != 0:
        # Retry with -u origin <branch>
        branch = subprocess.run(
            ["git", "branch", "--show-current"],
            capture_output=True,
            text=True,
            cwd=str(REPO_ROOT),
        ).stdout.strip()

        result = subprocess.run(
            ["git", "push", "-u", "origin", branch],
            capture_output=True,
            text=True,
            cwd=str(REPO_ROOT),
        )

    if result.returncode != 0:
        run.push_status = "failed"
        run.error = f"Push failed: {result.stderr.strip()[:200]}"
        run.save()
        log.error("Push failed: %s", result.stderr.strip())
        return False

    run.push_status = "pushed"
    run.save()
    log.info("Pushed to remote")
    return True
