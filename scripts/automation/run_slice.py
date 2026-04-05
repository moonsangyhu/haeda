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
)
from lib.state import RunState
from lib.worktree import cleanup_all

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("run_slice")


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
    """Show current status of a slice run."""
    rd = run_dir(slice_name)
    if not (rd / "run.json").exists():
        print(f"No run found for {slice_name}")
        return

    run = RunState.load(rd)
    print(f"Slice:   {run.slice_name}")
    print(f"Status:  {run.status}")
    print(f"Phase:   {run.phase}")
    print(f"QA:      {run.qa_verdict or 'N/A'}")
    print(f"Retries: {run.retry_count}")
    print(f"Started: {run.started_at or 'N/A'}")
    print(f"Ended:   {run.finished_at or 'N/A'}")

    if run.error:
        print(f"Error:   {run.error}")

    # Show task states
    for role in ("backend", "frontend", "qa"):
        task = run.get_task_state(role)
        print(f"\n  {role}:")
        print(f"    status: {task.status}")
        if task.started_at:
            print(f"    started: {task.started_at}")
        if task.finished_at:
            print(f"    finished: {task.finished_at}")
        if task.exit_code is not None:
            print(f"    exit_code: {task.exit_code}")


def clean_run(slice_name: str) -> None:
    """Clean up a slice run (artifacts + worktrees)."""
    rd = run_dir(slice_name)
    if rd.exists():
        shutil.rmtree(rd)
        print(f"Removed: {rd}")

    cleanup_all(slice_name)
    print(f"Cleaned worktrees for {slice_name}")


async def run_orchestrator(slice_name: str, resume: bool = False) -> None:
    """Main orchestration loop for a single slice."""
    rd = ensure_run_dirs(slice_name)

    # Load or create state
    if resume and (rd / "run.json").exists():
        run = RunState.load(rd)
        log.info("Resuming %s from phase: %s", slice_name, run.phase)
    else:
        run = RunState.create(slice_name, rd)
        run.save()
        log.info("Starting new run for %s", slice_name)

    plan = {}

    try:
        # PLAN phase
        if run.phase in ("plan", "pending"):
            plan = await phase_plan(run)
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
            await phase_build(run, plan)

        # MERGE phase
        if run.phase in ("build", "merge"):
            await phase_merge(run)

        # QA phase
        if run.phase in ("merge", "qa"):
            qa_data = await phase_qa(run, plan)
            verdict = qa_data.get("verdict", "incomplete")

            if verdict == "complete":
                await phase_complete(run, plan)
                _print_final(run)
                return

            # Not complete — try remediation
            if run.retry_count < MAX_REMEDIATION_RETRIES:
                await phase_remediate(run, qa_data)

                # Re-run QA
                qa_data = await phase_qa(run, plan, is_re_review=True)
                verdict = qa_data.get("verdict", "incomplete")

                if verdict == "complete":
                    await phase_complete(run, plan)
                    _print_final(run)
                    return

            # Still not complete after remediation
            run.mark_failed(
                f"QA verdict '{verdict}' after {run.retry_count} remediation(s). "
                "Manual intervention required."
            )
            _print_final(run)

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
                await phase_remediate(run, qa_data)
                qa_data = await phase_qa(run, plan, is_re_review=True)

                if qa_data.get("verdict") == "complete":
                    await phase_complete(run, plan)
                    _print_final(run)
                    return

            run.mark_failed("Remediation exhausted. Manual intervention required.")
            _print_final(run)

    except Exception as e:
        log.exception("Orchestrator error")
        if run.phase != PHASE_FAILED:
            run.mark_failed(str(e))
        _print_final(run)
        sys.exit(1)


def _print_final(run: RunState) -> None:
    """Print final status summary."""
    rd = run._run_dir
    print(f"\n{'=' * 50}")
    print(f"Slice:   {run.slice_name}")
    print(f"Status:  {run.status}")
    print(f"Phase:   {run.phase}")
    print(f"QA:      {run.qa_verdict or 'N/A'}")
    print(f"Retries: {run.retry_count}")

    if run.error:
        print(f"Error:   {run.error}")

    print(f"\nArtifacts: {rd}")
    print(f"  run.json          — compact state")
    if (rd / "results" / "summary.md").exists():
        print(f"  results/summary.md — final summary")
    if (rd / "results" / "qa-summary.md").exists():
        print(f"  results/qa-summary.md — QA details")
    print(f"  logs/             — full Claude output")
    print(f"{'=' * 50}")


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
    asyncio.run(run_orchestrator(slice_name, resume=args.resume))


if __name__ == "__main__":
    main()
