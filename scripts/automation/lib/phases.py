"""Phase orchestration for single-slice automation.

Phases: plan → build → merge → qa → (remediate → qa) → complete
Each phase reads minimal state, runs Claude, writes compact results.
"""

from __future__ import annotations

import asyncio
import json
import logging
from pathlib import Path

from .claude_runner import RunResult, resume_claude, run_claude
from .config import (
    MAX_CONTINUATION_RETRIES,
    MAX_TURNS_BACKEND,
    MAX_TURNS_CONTINUATION,
    MAX_TURNS_FRONTEND,
    MAX_TURNS_PLAN,
    MAX_TURNS_QA,
    MAX_TURNS_REMEDIATE,
    PHASE_BUILD,
    PHASE_COMPLETE,
    PHASE_FAILED,
    PHASE_MERGE,
    PHASE_PLAN,
    PHASE_QA,
    PHASE_REMEDIATE,
    REPO_ROOT,
)
from .prompts import (
    generate_backend_prompt,
    generate_continuation_prompt,
    generate_frontend_prompt,
    generate_plan_prompt,
    generate_qa_prompt,
    generate_re_review_prompt,
    generate_remediate_prompt,
    save_prompt,
)
from .state import RunState, TaskState
from .worktree import cleanup_all, commit_and_push, create_worktree, merge_worktree

log = logging.getLogger(__name__)


def _parse_json_result(text: str) -> dict:
    """Extract JSON from Claude's response, tolerating markdown fences."""
    text = text.strip()
    # Strip markdown code fences if present
    if text.startswith("```"):
        lines = text.split("\n")
        lines = [l for l in lines if not l.strip().startswith("```")]
        text = "\n".join(lines).strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        # Try to find JSON object in the text
        start = text.find("{")
        end = text.rfind("}") + 1
        if start >= 0 and end > start:
            return json.loads(text[start:end])
        raise


async def phase_plan(run: RunState) -> dict:
    """PLAN: Determine next slice scope via lightweight Claude call.

    Returns the plan dict (endpoints, screens, entities, goal).
    """
    log.info("=== PHASE: PLAN ===")
    run.transition(PHASE_PLAN)

    rd = run._run_dir
    prompt = generate_plan_prompt(run.slice_name)
    save_prompt(prompt, rd / "prompts" / "plan.md")

    result = await run_claude(
        prompt=prompt,
        cwd=REPO_ROOT,
        log_file=rd / "logs" / "plan.log",
        allowed_tools=["Read", "Glob", "Grep"],
        max_turns=MAX_TURNS_PLAN,
    )

    if result.exit_code != 0:
        run.mark_failed(f"Plan phase failed: {result.result_text[:200]}")
        raise RuntimeError("Plan phase failed")

    plan = _parse_json_result(result.result_text)

    if plan.get("all_p0_complete"):
        log.info("All P0 features are implemented!")
        run.status = PHASE_COMPLETE
        run.phase = PHASE_COMPLETE
        summary = "All MVP P0 features are implemented. No next slice needed."
        (rd / "results" / "summary.md").write_text(f"# {run.slice_name}\n\n{summary}\n")
        run.summary_file = "results/summary.md"
        run.save()
        return plan

    # Save plan summary (compact)
    summary_lines = [
        f"# {run.slice_name} Plan",
        f"\nGoal: {plan.get('goal', 'N/A')}",
        f"P0 ref: {plan.get('p0_reference', 'N/A')}",
        f"\n## Endpoints",
        *[f"- {ep}" for ep in plan.get("endpoints", [])],
        f"\n## Screens",
        *[f"- {s}" for s in plan.get("screens", [])],
        f"\n## Entities",
        *[f"- {e}" for e in plan.get("entities", [])],
        f"\n## Excluded",
        *[f"- {x}" for x in plan.get("excluded", [])],
    ]
    (rd / "results" / "plan-summary.md").write_text("\n".join(summary_lines) + "\n")

    return plan


async def _run_build_task(
    run: RunState,
    role: str,
    prompt: str,
    wt_path: Path,
    max_turns: int,
) -> RunResult:
    """Run a build task with automatic max-turns continuation (1 retry).

    If Claude hits the turn limit, we resume the same session with a short
    continuation prompt. This keeps all previous context without re-reading docs.
    """
    rd = run._run_dir
    log_file = rd / "logs" / f"{role}.log"
    allowed = ["Read", "Edit", "Write", "Bash", "Glob", "Grep"]

    result = await run_claude(
        prompt=prompt,
        cwd=wt_path,
        log_file=log_file,
        allowed_tools=allowed,
        max_turns=max_turns,
    )

    # If max-turns hit and we have a session to continue
    if result.is_max_turns and result.session_id:
        log.warning(
            "%s hit max turns (%d). Attempting continuation (session: %s)",
            role, max_turns, result.session_id[:12],
        )
        cont_prompt = generate_continuation_prompt(run.slice_name, role)
        save_prompt(cont_prompt, rd / "prompts" / f"{role}-continue.md")

        result = await resume_claude(
            session_id=result.session_id,
            prompt=cont_prompt,
            cwd=wt_path,
            log_file=log_file,
            allowed_tools=allowed,
            max_turns=MAX_TURNS_CONTINUATION,
        )

        if result.is_max_turns:
            log.error("%s hit max turns again after continuation. Giving up.", role)
            # Still return the result — let caller decide severity
        else:
            log.info("%s continuation completed successfully.", role)

    return result


def _task_succeeded(task: TaskState) -> bool:
    """Check if a task already completed successfully."""
    return task.status == "done" and task.exit_code == 0


async def phase_build(run: RunState, plan: dict) -> None:
    """BUILD: Run backend + frontend in parallel worktrees.

    Task-aware: on resume, skips tasks that already succeeded.
    Only reruns failed/pending tasks.
    """
    log.info("=== PHASE: BUILD ===")
    run.transition(PHASE_BUILD)

    rd = run._run_dir
    goal = plan.get("goal", "")
    endpoints = plan.get("endpoints", [])
    screens = plan.get("screens", [])
    entities = plan.get("entities", [])

    # Check existing task states for resume
    existing_be = run.get_task_state("backend")
    existing_fe = run.get_task_state("frontend")
    be_skip = _task_succeeded(existing_be)
    fe_skip = _task_succeeded(existing_fe)

    if be_skip and fe_skip:
        log.info("BUILD: both tasks already done, skipping to next phase")
        return

    if be_skip:
        log.info("BUILD: backend already done (exit=0), rerunning frontend only")
    if fe_skip:
        log.info("BUILD: frontend already done (exit=0), rerunning backend only")

    # Generate prompts (only for tasks we'll run; reuse existing if present)
    be_prompt = ""
    fe_prompt = ""
    if not be_skip:
        be_prompt = generate_backend_prompt(run.slice_name, goal, endpoints, entities)
        save_prompt(be_prompt, rd / "prompts" / "backend.md")
    if not fe_skip:
        fe_prompt = generate_frontend_prompt(run.slice_name, goal, screens, endpoints)
        save_prompt(fe_prompt, rd / "prompts" / "frontend.md")

    # Prepare worktrees + task states (only for tasks we'll run)
    results: dict[str, RunResult] = {}
    tasks_to_run: dict[str, TaskState] = {}

    if not be_skip:
        be_wt, be_branch = create_worktree(run.slice_name, "backend")
        be_task = TaskState(
            worktree_path=str(be_wt),
            worktree_branch=be_branch,
            prompt_file="prompts/backend.md",
            log_file="logs/backend.log",
        )
        be_task.mark_running()
        run.save_task_state("backend", be_task)
        tasks_to_run["backend"] = be_task

    if not fe_skip:
        fe_wt, fe_branch = create_worktree(run.slice_name, "frontend")
        fe_task = TaskState(
            worktree_path=str(fe_wt),
            worktree_branch=fe_branch,
            prompt_file="prompts/frontend.md",
            log_file="logs/frontend.log",
        )
        fe_task.mark_running()
        run.save_task_state("frontend", fe_task)
        tasks_to_run["frontend"] = fe_task

    run.save()

    # Build coroutines for tasks that need running
    coros = {}
    if "backend" in tasks_to_run:
        coros["backend"] = _run_build_task(
            run, "backend", be_prompt,
            Path(tasks_to_run["backend"].worktree_path), MAX_TURNS_BACKEND,
        )
    if "frontend" in tasks_to_run:
        coros["frontend"] = _run_build_task(
            run, "frontend", fe_prompt,
            Path(tasks_to_run["frontend"].worktree_path), MAX_TURNS_FRONTEND,
        )

    # Run in parallel
    gathered = await asyncio.gather(*coros.values())
    for role, result in zip(coros.keys(), gathered):
        results[role] = result

    # Update task states and save summaries for tasks we ran
    failed = []
    for role in ("backend", "frontend"):
        if role in results:
            result = results[role]
            task = tasks_to_run[role]
            task.mark_done(result.exit_code)
            task.result_summary_file = f"results/{role}-summary.md"
            if result.is_max_turns:
                task.error = "max_turns (even after continuation)"
            run.save_task_state(role, task)

            max_t = MAX_TURNS_BACKEND if role == "backend" else MAX_TURNS_FRONTEND
            status_str = "max_turns" if result.is_max_turns else f"exit={result.exit_code}"
            (rd / "results" / f"{role}-summary.md").write_text(
                f"# {role.title()} Result\n\n"
                f"Status: {status_str} | turns: {result.num_turns or '?'}/{max_t}\n\n"
                f"{result.result_text[:500]}\n"
            )

            if result.exit_code != 0:
                reason = "max_turns" if result.is_max_turns else f"exit={result.exit_code}"
                failed.append(f"{role}({reason})")
        else:
            # Skipped — log it
            log.info("BUILD: %s reused previous result (skipped)", role)

    if failed:
        run.mark_failed(f"Build failed: {', '.join(failed)}")
        raise RuntimeError(f"Build failed: {', '.join(failed)}")


async def phase_merge(run: RunState) -> None:
    """MERGE: Merge worktree branches back to main."""
    log.info("=== PHASE: MERGE ===")
    run.transition(PHASE_MERGE)

    be_task = run.get_task_state("backend")
    fe_task = run.get_task_state("frontend")

    # Merge backend first, then frontend
    for role, task in [("backend", be_task), ("frontend", fe_task)]:
        if task.worktree_branch:
            ok = merge_worktree(task.worktree_branch)
            if not ok:
                run.mark_failed(f"Merge failed for {role} branch: {task.worktree_branch}")
                raise RuntimeError(f"Merge failed for {role}")

    # Cleanup worktrees
    cleanup_all(run.slice_name)
    log.info("Merge complete, worktrees cleaned up")


async def phase_qa(run: RunState, plan: dict, *, is_re_review: bool = False) -> dict:
    """QA: Review the implementation. Returns QA result dict."""
    log.info("=== PHASE: QA %s===", "(re-review) " if is_re_review else "")
    run.transition(PHASE_QA)

    rd = run._run_dir

    if is_re_review:
        # Get previous blocking issues from QA summary
        qa_summary_path = rd / "results" / "qa-summary.md"
        prev_issues = []
        if qa_summary_path.exists():
            try:
                prev_data = json.loads(qa_summary_path.read_text().split("```json\n")[-1].split("\n```")[0])
                prev_issues = prev_data.get("blocking_issues", [])
            except (json.JSONDecodeError, IndexError):
                pass
        prompt = generate_re_review_prompt(run.slice_name, prev_issues)
        save_prompt(prompt, rd / "prompts" / "re-review.md")
    else:
        prompt = generate_qa_prompt(
            run.slice_name,
            plan.get("goal", ""),
            plan.get("endpoints", []),
            plan.get("screens", []),
        )
        save_prompt(prompt, rd / "prompts" / "qa.md")

    qa_task = TaskState(
        prompt_file="prompts/re-review.md" if is_re_review else "prompts/qa.md",
        log_file="logs/qa.log" if not is_re_review else "logs/qa-recheck.log",
    )
    qa_task.mark_running()
    run.save_task_state("qa", qa_task)
    run.save()

    result = await run_claude(
        prompt=prompt,
        cwd=REPO_ROOT,
        log_file=rd / "logs" / ("qa-recheck.log" if is_re_review else "qa.log"),
        allowed_tools=["Read", "Bash", "Glob", "Grep"],
        max_turns=MAX_TURNS_QA,
    )

    qa_task.mark_done(result.exit_code)
    run.save_task_state("qa", qa_task)

    # Parse QA result
    try:
        qa_data = _parse_json_result(result.result_text)
    except (json.JSONDecodeError, ValueError):
        log.warning("Could not parse QA JSON, treating as incomplete")
        qa_data = {"verdict": "incomplete", "blocking_issues": [{"area": "qa", "issue": "Failed to parse QA output"}]}

    verdict = qa_data.get("verdict", "incomplete")
    run.qa_verdict = verdict

    # Save QA summary (compact markdown + embedded JSON for machine reading)
    qa_summary = [
        f"# QA Result — {run.slice_name}",
        f"\nVerdict: **{verdict}**",
        f"Backend tests: {qa_data.get('tests_backend', 'N/A')}",
        f"Frontend tests: {qa_data.get('tests_frontend', 'N/A')}",
    ]
    if qa_data.get("blocking_issues"):
        qa_summary.append("\n## Blocking Issues")
        for iss in qa_data["blocking_issues"]:
            qa_summary.append(f"- [{iss.get('area', '?')}] {iss.get('file', '?')}: {iss.get('issue', '?')}")
    qa_summary.append(f"\n```json\n{json.dumps(qa_data, indent=2, ensure_ascii=False)}\n```")

    (rd / "results" / "qa-summary.md").write_text("\n".join(qa_summary) + "\n")
    run.qa_summary_file = "results/qa-summary.md"
    run.save()

    return qa_data


async def phase_remediate(run: RunState, qa_data: dict) -> None:
    """REMEDIATE: Fix blocking issues found by QA (max 1 retry)."""
    log.info("=== PHASE: REMEDIATE ===")
    run.transition(PHASE_REMEDIATE)
    run.retry_count += 1

    rd = run._run_dir
    blocking = qa_data.get("blocking_issues", [])

    # Split issues by area
    be_issues = [i for i in blocking if i.get("area") == "backend"]
    fe_issues = [i for i in blocking if i.get("area") == "frontend"]

    tasks = []

    if be_issues:
        be_prompt = generate_remediate_prompt(run.slice_name, "backend", be_issues)
        save_prompt(be_prompt, rd / "prompts" / "backend-remediate.md")
        tasks.append(("backend", be_prompt, be_issues))

    if fe_issues:
        fe_prompt = generate_remediate_prompt(run.slice_name, "frontend", fe_issues)
        save_prompt(fe_prompt, rd / "prompts" / "frontend-remediate.md")
        tasks.append(("frontend", fe_prompt, fe_issues))

    if not tasks:
        # No categorized issues — fail
        run.mark_failed("QA found blocking issues but none categorized to backend/frontend")
        raise RuntimeError("Cannot remediate: uncategorized issues")

    # Run remediation (parallel if both, sequential if one)
    coros = []
    for role, prompt, _ in tasks:
        log_name = f"{role}-remediate.log"
        coros.append(
            run_claude(
                prompt=prompt,
                cwd=REPO_ROOT,
                log_file=rd / "logs" / log_name,
                allowed_tools=["Read", "Edit", "Write", "Bash", "Glob", "Grep"],
                max_turns=MAX_TURNS_REMEDIATE,
            )
        )

    results = await asyncio.gather(*coros)

    for (role, _, _), result in zip(tasks, results):
        if result.exit_code != 0:
            log.warning("Remediation failed for %s (exit %d)", role, result.exit_code)


async def phase_complete(run: RunState, plan: dict) -> None:
    """COMPLETE: Commit, push, and generate final summary."""
    log.info("=== PHASE: COMPLETE ===")
    run.transition(PHASE_COMPLETE)

    rd = run._run_dir

    # Commit + push
    pushed = commit_and_push(run.slice_name)

    summary = [
        f"# {run.slice_name} — Complete",
        f"\n## Goal\n{plan.get('goal', 'N/A')}",
        f"\n## Verdict: {run.qa_verdict}",
        f"Retries: {run.retry_count}",
        f"Git push: {'OK' if pushed else 'FAILED (manual push required)'}",
        f"\n## Artifacts",
        f"- Run state: run.json",
        f"- QA summary: {run.qa_summary_file}",
        f"- Backend log: logs/backend.log",
        f"- Frontend log: logs/frontend.log",
        f"- QA log: logs/qa.log",
    ]

    (rd / "results" / "summary.md").write_text("\n".join(summary) + "\n")
    run.summary_file = "results/summary.md"
    from .state import _now
    run.finished_at = _now()
    run.save()

    if not pushed:
        log.warning("Auto-push failed. Run 'git push' manually.")
    log.info("Slice %s completed successfully!", run.slice_name)
