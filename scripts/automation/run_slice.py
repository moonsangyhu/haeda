#!/usr/bin/env python3
"""Single-slice automation orchestrator for Haeda MVP.

Usage:
    python scripts/automation/run_slice.py --slice slice-07
    python scripts/automation/run_slice.py --slice slice-07 --resume
    python scripts/automation/run_slice.py --slice slice-07 --status
    python scripts/automation/run_slice.py --slice slice-07 --clean
    python scripts/automation/run_slice.py --auto  # auto-detect next slice

Token-saving design:
- State files are compact JSON with path pointers only.
- Prompts tell Claude to READ docs, not embed them.
- Logs go to separate files, never into state.
- Each Claude call gets minimal context (current phase only).
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import re
import shutil
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

# Add lib to path
sys.path.insert(0, str(Path(__file__).parent))

from lib.config import (
    MAX_REMEDIATION_RETRIES,
    PHASE_COMPLETE,
    PHASE_FAILED,
    RUNS_DIR,
    TEST_REPORTS_DIR,
    ensure_run_dirs,
    run_dir,
)
from lib.phases import (
    phase_build,
    phase_complete,
    phase_merge,
    phase_plan,
    phase_qa,
    phase_remediate,
    phase_verify,
)
from lib.state import RunState
from lib.worktree import cleanup_all

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("run_slice")

DEFAULT_WATCH_INTERVAL = 10


# ---------------------------------------------------------------------------
# Progress Reporter — async heartbeat that prints compact status every N sec
# ---------------------------------------------------------------------------

def _elapsed(iso_ts: str | None) -> str:
    """Compute human-readable elapsed time from an ISO timestamp to now."""
    if not iso_ts:
        return "-"
    try:
        start = datetime.fromisoformat(iso_ts)
        delta = datetime.now(timezone.utc) - start
        secs = int(delta.total_seconds())
        if secs < 0:
            return "0s"
        if secs < 60:
            return f"{secs}s"
        mins, secs = divmod(secs, 60)
        return f"{mins}m{secs:02d}s"
    except (ValueError, TypeError):
        return "?"


def _task_label(run: RunState, role: str) -> str:
    """Build a compact label like 'running(42s)' for a task."""
    task = run.get_task_state(role)
    status = task.status
    if status == "running":
        return f"running({_elapsed(task.started_at)})"
    if status == "done":
        return f"done({_elapsed(task.started_at)})"
    if status == "failed":
        return "FAILED"
    return status  # pending / skipped


def format_heartbeat(run: RunState) -> str:
    """Format a single compact heartbeat line."""
    ts = datetime.now().strftime("%H:%M:%S")
    be = _task_label(run, "backend")
    fe = _task_label(run, "frontend")
    qa = _task_label(run, "qa")
    elapsed = _elapsed(run.started_at)
    return (
        f"[{ts}] {run.slice_name} | phase={run.phase} | retry={run.retry_count} | "
        f"backend={be} | frontend={fe} | qa={qa} | total={elapsed}"
    )


class ProgressReporter:
    """Async background task that prints heartbeat lines at a fixed interval.

    Reads from the in-memory RunState object — no extra disk I/O.
    Does NOT inflate state files or store anything.
    """

    def __init__(self, run: RunState, interval: float = DEFAULT_WATCH_INTERVAL):
        self._run = run
        self._interval = interval
        self._task: asyncio.Task | None = None
        self._last_phase: str | None = None

    def start(self) -> None:
        if self._interval <= 0:
            return
        self._task = asyncio.create_task(self._loop())

    async def stop(self) -> None:
        if self._task and not self._task.done():
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        # Print final heartbeat
        self._print()

    def notify_phase_change(self) -> None:
        """Call when phase changes to get an immediate extra heartbeat."""
        phase = self._run.phase
        if phase != self._last_phase:
            self._last_phase = phase
            self._print()

    def _print(self) -> None:
        print(format_heartbeat(self._run), flush=True)

    async def _loop(self) -> None:
        try:
            while True:
                await asyncio.sleep(self._interval)
                self._print()
        except asyncio.CancelledError:
            pass


def detect_next_slice() -> str:
    """Auto-detect the next slice number from existing test reports."""
    if not TEST_REPORTS_DIR.exists():
        return "slice-07"  # Default start

    reports = sorted(TEST_REPORTS_DIR.glob("slice-*-test-report.md"))
    if not reports:
        return "slice-07"

    # Extract highest slice number
    max_num = 0
    for r in reports:
        m = re.search(r"slice-(\d+)", r.name)
        if m:
            max_num = max(max_num, int(m.group(1)))

    return f"slice-{max_num + 1:02d}"


def show_status(slice_name: str) -> None:
    """Show current status of a slice run (compact format, same as heartbeat)."""
    rd = run_dir(slice_name)
    if not (rd / "run.json").exists():
        print(f"No run found for {slice_name}")
        return

    run = RunState.load(rd)

    # Compact one-liner (same format as heartbeat)
    print(format_heartbeat(run))

    # Extra detail block
    print(f"\n  started: {run.started_at or 'N/A'}")
    if run.finished_at:
        print(f"  ended:   {run.finished_at}")
    if run.qa_verdict:
        print(f"  qa:      {run.qa_verdict}")
    if run.error:
        print(f"  error:   {run.error}")

    for role in ("backend", "frontend", "qa"):
        task = run.get_task_state(role)
        if task.status == "pending":
            continue
        extra = []
        if task.exit_code is not None:
            extra.append(f"exit={task.exit_code}")
        if task.error:
            extra.append(f"err={task.error[:60]}")
        suffix = f" ({', '.join(extra)})" if extra else ""
        print(f"  {role}: {task.status}{suffix}")


def _resolve_resume_phase(run: RunState) -> str:
    """When phase=failed, determine which phase to actually resume from.

    Inspects task states and artifacts to find the last successful phase,
    then returns the next phase to attempt.
    """
    rd = run._run_dir

    # No plan → start from plan
    if not (rd / "results" / "plan-summary.md").exists():
        return "plan"

    be = run.get_task_state("backend")
    fe = run.get_task_state("frontend")
    qa = run.get_task_state("qa")

    # Either build task not done → resume build
    if be.status != "done" or fe.status != "done":
        return "build"

    # Build done but QA never ran → merge then QA
    if qa.status == "pending":
        return "merge"

    # QA ran but not complete → re-run QA (or remediate if retries left)
    if run.qa_verdict and run.qa_verdict != "complete":
        return "qa"

    # QA complete but verify not passed → resume from verify
    if run.qa_verdict == "complete" and run.verify_status != "passed":
        return "verify"

    # Fallback: re-run from build
    return "build"


def clean_run(slice_name: str) -> None:
    """Clean up a slice run (artifacts + worktrees)."""
    rd = run_dir(slice_name)
    if rd.exists():
        shutil.rmtree(rd)
        print(f"Removed: {rd}")

    cleanup_all(slice_name)
    print(f"Cleaned worktrees for {slice_name}")


async def run_orchestrator(
    slice_name: str,
    resume: bool = False,
    watch_interval: float = DEFAULT_WATCH_INTERVAL,
) -> None:
    """Main orchestration loop for a single slice."""
    rd = ensure_run_dirs(slice_name)

    # Load or create state
    if resume and (rd / "run.json").exists():
        run = RunState.load(rd)
        if run.phase in ("failed", "incomplete"):
            resolved = _resolve_resume_phase(run)
            log.info(
                "Resuming %s: phase was '%s' (error: %s) → resuming from '%s'",
                slice_name, run.phase, (run.error or "?")[:80], resolved,
            )
            run.phase = resolved
            run.status = resolved
            run.error = None
            run.finished_at = None
            run.save()
        else:
            log.info("Resuming %s from phase: %s", slice_name, run.phase)
    else:
        run = RunState.create(slice_name, rd)
        run.save()
        log.info("Starting new run for %s", slice_name)

    # Banner
    print(f"\n{'=' * 60}")
    print(f"  Slice:     {slice_name}")
    print(f"  Run dir:   {rd}")
    print(f"  Heartbeat: every {watch_interval}s" if watch_interval > 0 else "  Heartbeat: off")
    print(f"{'=' * 60}\n")

    # Start heartbeat reporter
    reporter = ProgressReporter(run, interval=watch_interval)
    reporter.start()

    plan = {}

    try:
        # PLAN phase
        if run.phase in ("plan", "pending"):
            reporter.notify_phase_change()
            plan = await phase_plan(run)
            reporter.notify_phase_change()
            if plan.get("all_p0_complete"):
                print("\n=== ALL P0 FEATURES COMPLETE ===")
                print("No more slices to implement.")
                return

        # RESUME: reload plan from saved summary if skipping plan phase
        if not plan:
            plan_summary = rd / "results" / "plan-summary.md"
            if plan_summary.exists():
                # Minimal plan reconstruction from summary
                plan = {"goal": "resumed", "endpoints": [], "screens": [], "entities": []}
            else:
                log.error("No plan found. Cannot resume without plan phase.")
                run.mark_failed("No plan found for resume")
                return

        # BUILD phase
        if run.phase in ("plan", "build"):
            reporter.notify_phase_change()
            await phase_build(run, plan)
            reporter.notify_phase_change()

        # MERGE phase
        if run.phase in ("build", "merge"):
            reporter.notify_phase_change()
            await phase_merge(run)
            reporter.notify_phase_change()

        # Helper: verify → complete sequence
        async def _verify_and_complete():
            reporter.notify_phase_change()
            await phase_verify(run)
            reporter.notify_phase_change()
            await phase_complete(run, plan)
            reporter.notify_phase_change()
            _print_final(run)

        # QA phase
        if run.phase in ("merge", "qa"):
            reporter.notify_phase_change()
            qa_data = await phase_qa(run, plan)
            reporter.notify_phase_change()
            verdict = qa_data.get("verdict", "incomplete")

            if verdict == "complete":
                await _verify_and_complete()
                return

            # Not complete — try remediation
            if run.retry_count < MAX_REMEDIATION_RETRIES:
                reporter.notify_phase_change()
                await phase_remediate(run, qa_data)
                reporter.notify_phase_change()

                # Re-run QA
                qa_data = await phase_qa(run, plan, is_re_review=True)
                reporter.notify_phase_change()
                verdict = qa_data.get("verdict", "incomplete")

                if verdict == "complete":
                    await _verify_and_complete()
                    return

            # Still not complete after remediation
            run.mark_failed(
                f"QA verdict '{verdict}' after {run.retry_count} remediation(s). "
                "Manual intervention required."
            )
            _print_final(run)

        # VERIFY phase (resume directly into verify)
        if run.phase == "verify":
            await _verify_and_complete()
            return

        # REMEDIATE phase (resume into remediate)
        if run.phase == "remediate":
            # Load QA data from summary
            qa_summary = rd / "results" / "qa-summary.md"
            qa_data = {}
            if qa_summary.exists():
                try:
                    text = qa_summary.read_text()
                    json_match = text.split("```json\n")[-1].split("\n```")[0]
                    qa_data = json.loads(json_match)
                except (json.JSONDecodeError, IndexError):
                    pass

            if run.retry_count < MAX_REMEDIATION_RETRIES:
                reporter.notify_phase_change()
                await phase_remediate(run, qa_data)
                reporter.notify_phase_change()
                qa_data = await phase_qa(run, plan, is_re_review=True)
                reporter.notify_phase_change()

                if qa_data.get("verdict") == "complete":
                    await _verify_and_complete()
                    return

            run.mark_failed("Remediation exhausted. Manual intervention required.")
            _print_final(run)

    except Exception as e:
        log.exception("Orchestrator error")
        if run.phase != PHASE_FAILED:
            run.mark_failed(str(e))
        _print_final(run)
        sys.exit(1)
    finally:
        await reporter.stop()


def _print_final(run: RunState) -> None:
    """Print final status summary with git status and verify info."""
    from lib.phases import _get_git_status
    from lib.config import TEST_REPORTS_DIR

    rd = run._run_dir
    git = _get_git_status()
    report_exists = (TEST_REPORTS_DIR / f"{run.slice_name}-test-report.md").exists()

    print(f"\n{'=' * 60}")
    print(f"  Slice:    {run.slice_name}")
    print(f"  Status:   {run.status}")
    print(f"  Phase:    {run.phase}")
    print(f"  QA:       {run.qa_verdict or 'N/A'}")
    print(f"  Verify:   {run.verify_status or 'N/A'}")
    print(f"  Retries:  {run.retry_count}")
    print(f"  Report:   {'YES' if report_exists else 'MISSING'}")
    print(f"  Git:      {git['dirty_count']} uncommitted, {git['ahead_count']} unpushed")

    if run.error:
        print(f"  Error:    {run.error}")

    # Next actions
    actions = []
    if git["needs_commit"]:
        actions.append("git add -A && git commit")
    if git["needs_push"]:
        actions.append("git push")
    if not report_exists and run.status != "failed":
        actions.append("generate test-report")

    if actions:
        print(f"\n  Next:     {' → '.join(actions)}")

    print(f"\n  Artifacts: {rd}")
    if (rd / "results" / "summary.md").exists():
        print(f"    results/summary.md")
    if (rd / "results" / "verify-summary.md").exists():
        print(f"    results/verify-summary.md")
    print(f"    logs/")
    print(f"{'=' * 60}")


def main():
    parser = argparse.ArgumentParser(
        description="Haeda single-slice automation orchestrator"
    )
    parser.add_argument(
        "--slice", "-s",
        help="Slice name (e.g., slice-07). Omit with --auto to detect.",
    )
    parser.add_argument(
        "--auto", "-a",
        action="store_true",
        help="Auto-detect next slice from test-reports/",
    )
    parser.add_argument(
        "--resume", "-r",
        action="store_true",
        help="Resume a previously started run",
    )
    parser.add_argument(
        "--status",
        action="store_true",
        help="Show current status of a slice run",
    )
    parser.add_argument(
        "--clean",
        action="store_true",
        help="Clean up a slice run (artifacts + worktrees)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be done without executing",
    )
    parser.add_argument(
        "--watch-interval", "-w",
        type=float,
        default=DEFAULT_WATCH_INTERVAL,
        help=f"Heartbeat interval in seconds (default: {DEFAULT_WATCH_INTERVAL})",
    )
    parser.add_argument(
        "--quiet", "-q",
        action="store_true",
        help="Disable heartbeat output",
    )
    args = parser.parse_args()

    # Determine slice name
    if args.auto:
        slice_name = detect_next_slice()
        print(f"Auto-detected next slice: {slice_name}")
    elif args.slice:
        slice_name = args.slice
    else:
        parser.error("Provide --slice NAME or --auto")
        return

    # Handle commands
    if args.status:
        show_status(slice_name)
        return

    if args.clean:
        clean_run(slice_name)
        return

    if args.dry_run:
        print(f"Would run slice: {slice_name}")
        print(f"Run dir: {run_dir(slice_name)}")
        print(f"Resume: {args.resume}")
        return

    # Run orchestrator
    interval = 0 if args.quiet else args.watch_interval
    asyncio.run(run_orchestrator(slice_name, resume=args.resume, watch_interval=interval))


if __name__ == "__main__":
    main()
