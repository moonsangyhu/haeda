#!/usr/bin/env python3
"""Refinement pipeline orchestrator for Haeda.

User-request-driven feedback loop:
  analyze -> implement -> verify -> report -> commit -> push

Usage:
    # New refinement (inline request)
    python scripts/automation/run_refine.py --request "fix badge spacing"

    # New refinement (file-based request, preferred for long descriptions)
    python scripts/automation/run_refine.py --request-file requests/badge-fix.md

    # With auto-push
    python scripts/automation/run_refine.py --request-file req.md --auto-push 1

    # Status / resume / clean / list
    python scripts/automation/run_refine.py --run refine-20260405-001 --status
    python scripts/automation/run_refine.py --run refine-20260405-001 --resume
    python scripts/automation/run_refine.py --run refine-20260405-001 --clean
    python scripts/automation/run_refine.py --list

Token-saving design (same as run_slice.py):
- State files are compact JSON with path pointers.
- Prompts tell Claude to READ docs, not embed them.
- Logs in separate files. Reports in separate markdown.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

# Add lib to path
sys.path.insert(0, str(Path(__file__).parent))

from lib.config import (
    MAX_REMEDIATION_RETRIES,
    REPO_ROOT,
    RUNS_DIR,
    ensure_run_dirs,
    run_dir,
)
from lib.phases import _get_git_status, check_repo_clean
from lib.refine_phases import (
    phase_analyze,
    phase_commit,
    phase_implement,
    phase_push,
    phase_report,
    phase_verify,
)
from lib.refine_state import RefineState

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("run_refine")

DEFAULT_WATCH_INTERVAL = 10


# ---------------------------------------------------------------------------
# Progress Reporter — async heartbeat (mirrors run_slice.py pattern)
# ---------------------------------------------------------------------------

_PHASE_ACTIONS = {
    "pending": "starting",
    "analyze": "analyzing",
    "implement": "implementing",
    "verify": "verifying",
    "report": "reporting",
    "commit": "committing",
    "push": "pushing",
    "complete": "done",
    "failed": "failed",
}


def _elapsed(iso_ts: str | None) -> str:
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


def format_heartbeat(run: RefineState) -> str:
    """Format a single compact heartbeat line for refinement."""
    ts = datetime.now().strftime("%H:%M:%S")
    action = _PHASE_ACTIONS.get(run.phase, run.phase)
    area = run.affected_area or "?"
    elapsed = _elapsed(run.started_at)
    verdict = run.verify_verdict or "-"
    retry = run.retry_count

    return (
        f"[{ts}] {run.run_id} | phase={run.phase}:{action} | "
        f"area={area} | verify={verdict} | retry={retry} | total={elapsed}"
    )


class ProgressReporter:
    """Async background task that prints heartbeat lines at a fixed interval.

    Reads from the in-memory RefineState — no extra disk I/O.
    """

    def __init__(self, run: RefineState, interval: float = DEFAULT_WATCH_INTERVAL):
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
        """Call on phase change for an immediate extra heartbeat."""
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


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def generate_run_id() -> str:
    """Generate a unique run ID: refine-YYYYMMDD-NNN."""
    today = datetime.now().strftime("%Y%m%d")
    prefix = f"refine-{today}-"
    RUNS_DIR.mkdir(parents=True, exist_ok=True)
    existing = sorted(p for p in RUNS_DIR.iterdir() if p.name.startswith(prefix))
    if existing:
        last_num = int(existing[-1].name.split("-")[-1])
        return f"{prefix}{last_num + 1:03d}"
    return f"{prefix}001"


def parse_request_file(path: str) -> dict:
    """Parse a request file. Supports plain text or structured format.

    Structured format (all sections optional):
        ## Request
        The actual request text

        ## Why
        Reason for the change

        ## Acceptance Criteria
        - criterion 1
        - criterion 2

        ## Out of Scope
        - exclusion 1

    Returns dict with keys: text, acceptance_criteria, out_of_scope.
    """
    p = Path(path)
    if not p.is_absolute():
        p = REPO_ROOT / p
    if not p.exists():
        raise FileNotFoundError(f"Request file not found: {p}")

    content = p.read_text().strip()
    result = {"text": content, "acceptance_criteria": [], "out_of_scope": []}

    # Try to parse structured format
    sections: dict[str, list[str]] = {}
    current: str | None = None
    for line in content.split("\n"):
        header = re.match(r"^##\s+(.+)", line)
        if header:
            current = header.group(1).strip().lower()
            sections[current] = []
        elif current is not None:
            sections[current].append(line)

    if sections:
        # Build request text from Request + Why sections
        text_parts = []
        if "request" in sections:
            text_parts.append("\n".join(sections["request"]).strip())
        if "why" in sections:
            why_text = "\n".join(sections["why"]).strip()
            if why_text:
                text_parts.append(f"Why: {why_text}")
        if text_parts:
            result["text"] = "\n\n".join(text_parts)

        if "acceptance criteria" in sections:
            result["acceptance_criteria"] = [
                l.strip().lstrip("- ")
                for l in sections["acceptance criteria"]
                if l.strip().startswith("-")
            ]

        if "out of scope" in sections:
            result["out_of_scope"] = [
                l.strip().lstrip("- ")
                for l in sections["out of scope"]
                if l.strip().startswith("-")
            ]

    return result


# ---------------------------------------------------------------------------
# Orchestrator
# ---------------------------------------------------------------------------


async def run_refinement(
    request_text: str,
    *,
    request_file: str | None = None,
    auto_push: bool = False,
    run_id: str | None = None,
    resume: bool = False,
    watch_interval: float = DEFAULT_WATCH_INTERVAL,
) -> None:
    """Main refinement orchestration loop."""

    # Dirty repo guard
    is_clean, real_dirty, runtime_dirty = check_repo_clean()
    if not is_clean:
        print(f"\n{'=' * 60}")
        print(f"  ERROR: Repository has uncommitted changes ({len(real_dirty)} files)")
        for f in real_dirty[:10]:
            print(f"    {f}")
        print(f"\n  Commit or stash first:")
        print(f"    git add -A && git commit -m 'wip: save progress'")
        print(f"{'=' * 60}")
        sys.exit(1)
    if runtime_dirty:
        log.info(
            "Runtime artifacts found (%d files) — ignored by dirty guard",
            len(runtime_dirty),
        )

    # Create or load state
    if resume and run_id:
        rd = run_dir(run_id)
        if not (rd / "run.json").exists():
            print(f"No run found: {run_id}")
            sys.exit(1)
        run = RefineState.load(rd)
        if run.phase == "failed":
            # Smart resume: find last successful phase
            resolved = _resolve_resume_phase(run)
            log.info(
                "Resuming %s: was '%s' -> resuming from '%s'",
                run_id,
                run.phase,
                resolved,
            )
            run.phase = resolved
            run.status = resolved
            run.error = None
            run.finished_at = None
            run.save()
        else:
            log.info("Resuming %s from phase: %s", run_id, run.phase)
    else:
        run_id = run_id or generate_run_id()
        rd = ensure_run_dirs(run_id)
        run = RefineState.create(
            run_id=run_id,
            run_dir=rd,
            request_text=request_text,
            request_file=request_file,
            auto_push=auto_push,
        )
        # Save original request as separate file
        (rd / "request.md").write_text(request_text)
        run.save()
        log.info("Starting refinement: %s", run_id)

    # Banner
    short_req = request_text[:80] + ("..." if len(request_text) > 80 else "")
    print(f"\n{'=' * 60}")
    print(f"  Run:      {run.run_id}")
    print(f"  Request:  {short_req}")
    print(f"  Push:     {'auto' if auto_push else 'manual (commit only)'}")
    print(f"  Heartbeat: every {watch_interval}s" if watch_interval > 0 else "  Heartbeat: off")
    print(f"  Run dir:  {rd}")
    print(f"{'=' * 60}\n")

    # Start heartbeat reporter
    reporter = ProgressReporter(run, interval=watch_interval)
    reporter.start()

    analysis = {}
    verify_data = {}

    # Pre-parse user criteria from request file (if structured)
    user_criteria = None
    user_oos = None
    if request_file:
        try:
            parsed = parse_request_file(request_file)
            user_criteria = parsed.get("acceptance_criteria") or None
            user_oos = parsed.get("out_of_scope") or None
        except Exception:
            pass

    try:
        # ANALYZE
        if run.phase in ("analyze", "pending"):
            reporter.notify_phase_change()
            analysis = await phase_analyze(
                run,
                user_criteria=user_criteria,
                user_out_of_scope=user_oos,
            )
            reporter.notify_phase_change()

        # Load analysis if resuming past analyze
        if not analysis and run.analysis_file:
            analysis_path = rd / run.analysis_file
            if analysis_path.exists():
                analysis = json.loads(analysis_path.read_text())

        if not analysis:
            run.mark_failed("No analysis found — cannot proceed")
            _print_final(run)
            return

        # IMPLEMENT
        if run.phase in ("analyze", "implement"):
            reporter.notify_phase_change()
            await phase_implement(run, analysis)
            reporter.notify_phase_change()

        # VERIFY
        if run.phase in ("implement", "verify"):
            reporter.notify_phase_change()
            verify_data = await phase_verify(run, analysis)
            reporter.notify_phase_change()

            # Remediation loop (max 1 retry)
            if (
                verify_data.get("verdict") != "passed"
                and run.retry_count < MAX_REMEDIATION_RETRIES
            ):
                run.retry_count += 1
                run.save()
                log.info(
                    "Verify failed — remediation attempt %d", run.retry_count
                )
                reporter.notify_phase_change()
                await phase_implement(run, analysis, is_remediation=True)
                reporter.notify_phase_change()
                verify_data = await phase_verify(run, analysis)
                reporter.notify_phase_change()

            if verify_data.get("verdict") != "passed":
                run.mark_failed(
                    f"Verify failed after {run.retry_count} retry(s): "
                    f"{verify_data.get('failure_reason', 'unknown')}"
                )
                phase_report(run, analysis, verify_data)
                _print_final(run)
                return

        # Load verify data if resuming past verify
        if not verify_data:
            vpath = rd / "results" / "verify-summary.json"
            if vpath.exists():
                verify_data = json.loads(vpath.read_text())

        # REPORT
        if run.phase in ("verify", "report"):
            reporter.notify_phase_change()
            phase_report(run, analysis, verify_data or {})
            reporter.notify_phase_change()

        # COMMIT
        if run.phase in ("report", "commit"):
            reporter.notify_phase_change()
            commit_hash = phase_commit(run, analysis)
            reporter.notify_phase_change()

        # PUSH
        if run.phase in ("commit", "push"):
            reporter.notify_phase_change()
            if run.auto_push:
                phase_push(run)
            else:
                run.push_status = "skipped"
                run.save()
            reporter.notify_phase_change()

        # COMPLETE
        run.status = "complete"
        run.phase = "complete"
        run.finished_at = datetime.now(timezone.utc).isoformat(timespec="seconds")
        run.save()
        reporter.notify_phase_change()

        _print_final(run)

    except Exception as e:
        log.exception("Refinement error")
        if run.phase != "failed":
            run.mark_failed(str(e))
        _print_final(run)
        sys.exit(1)
    finally:
        await reporter.stop()


def _resolve_resume_phase(run: RefineState) -> str:
    """Determine which phase to resume from after failure."""
    rd = run._run_dir

    # No analysis → start from analyze
    if not (rd / "results" / "analysis.json").exists():
        return "analyze"

    # No implement summary → start from implement
    has_impl = any((rd / "results").glob("implement-*-summary.md"))
    if not has_impl:
        return "implement"

    # No verify → start from verify
    if not (rd / "results" / "verify-summary.json").exists():
        return "verify"

    # Verify failed → retry implement (if retries left)
    if run.verify_verdict != "passed" and run.retry_count < MAX_REMEDIATION_RETRIES:
        return "implement"

    # No report → generate report
    if not (rd / "results" / "report.md").exists():
        return "report"

    # No commit → commit
    if not run.commit_hash:
        return "commit"

    # Not pushed → push
    if run.push_status == "pending":
        return "push"

    return "analyze"  # fallback: start over


# ---------------------------------------------------------------------------
# Status / list / clean
# ---------------------------------------------------------------------------


def _print_final(run: RefineState) -> None:
    """Print final summary."""
    git = _get_git_status()

    print(f"\n{'=' * 60}")
    print(f"  Run:      {run.run_id}")
    print(f"  Status:   {run.status}")
    print(f"  Area:     {run.affected_area or 'N/A'}")
    print(f"  Verify:   {run.verify_verdict or 'N/A'}")
    print(f"  Retries:  {run.retry_count}")
    print(f"  Commit:   {run.commit_hash or 'N/A'}")
    print(f"  Push:     {run.push_status}")
    print(f"  Git:      {git['dirty_count']} uncommitted, {git['ahead_count']} unpushed")

    if run.error:
        print(f"  Error:    {run.error}")

    rd = run._run_dir
    if rd:
        print(f"\n  Artifacts: {rd}")
        if run.report_file:
            print(f"    {run.report_file}")
        print(f"    logs/")

    # Next action
    if run.status == "complete":
        if run.push_status == "skipped" and run.commit_hash:
            print(f"\n  Next: git push  (or: make refine AUTO_PUSH=1 ...)")
        else:
            print(f"\n  Done. Ready for next refinement.")
    elif run.status == "failed":
        print(f"\n  Next: make refine-resume RUN={run.run_id}")

    print(f"{'=' * 60}")


def show_status(run_id: str) -> None:
    """Show status of a refinement run."""
    rd = run_dir(run_id)
    if not (rd / "run.json").exists():
        print(f"No run found: {run_id}")
        return
    run = RefineState.load(rd)
    _print_final(run)


def list_runs() -> None:
    """List all refinement runs (most recent first)."""
    if not RUNS_DIR.exists():
        print("No runs found.")
        return

    refine_dirs = sorted(
        [d for d in RUNS_DIR.iterdir() if d.is_dir() and d.name.startswith("refine-")],
        reverse=True,
    )

    if not refine_dirs:
        print("No refinement runs found.")
        return

    fmt = "{:<28} {:<12} {:<10} {:<10} {:<8}"
    print(fmt.format("Run ID", "Status", "Area", "Commit", "Push"))
    print("-" * 68)
    for d in refine_dirs[:20]:
        try:
            run = RefineState.load(d)
            print(
                fmt.format(
                    run.run_id,
                    run.status,
                    run.affected_area or "-",
                    run.commit_hash or "-",
                    run.push_status,
                )
            )
        except Exception:
            print(fmt.format(d.name, "error", "-", "-", "-"))


def clean_run(run_id: str) -> None:
    """Remove all artifacts for a refinement run."""
    rd = run_dir(run_id)
    if rd.exists():
        shutil.rmtree(rd)
        print(f"Removed: {rd}")
    else:
        print(f"Not found: {rd}")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Haeda refinement pipeline — user-request-driven feedback loop"
    )
    parser.add_argument("--request", "-r", help="Inline request text")
    parser.add_argument("--request-file", "-f", help="Path to request file (.md)")
    parser.add_argument("--run", help="Run ID (for --status/--resume/--clean)")
    parser.add_argument(
        "--auto-push",
        type=int,
        default=0,
        help="0=commit only (default), 1=commit+push",
    )
    parser.add_argument("--resume", action="store_true", help="Resume a failed/interrupted run")
    parser.add_argument("--status", action="store_true", help="Show run status")
    parser.add_argument("--clean", action="store_true", help="Remove run artifacts")
    parser.add_argument("--list", action="store_true", help="List all refinement runs")
    parser.add_argument(
        "--watch-interval", "-w",
        type=float,
        default=DEFAULT_WATCH_INTERVAL,
        help=f"Heartbeat interval in seconds (default: {DEFAULT_WATCH_INTERVAL})",
    )
    parser.add_argument("--quiet", "-q", action="store_true", help="Disable heartbeat output")

    args = parser.parse_args()

    # Dispatch
    if args.list:
        list_runs()
        return

    if args.status:
        if not args.run:
            parser.error("--run required with --status")
        show_status(args.run)
        return

    if args.clean:
        if not args.run:
            parser.error("--run required with --clean")
        clean_run(args.run)
        return

    # Resolve watch interval
    interval = 0 if args.quiet else args.watch_interval

    if args.resume:
        if not args.run:
            parser.error("--run required with --resume")
        rd = run_dir(args.run)
        if not (rd / "run.json").exists():
            print(f"No run found: {args.run}")
            sys.exit(1)
        run = RefineState.load(rd)
        asyncio.run(
            run_refinement(
                run.request_text,
                request_file=run.request_file,
                run_id=args.run,
                auto_push=bool(args.auto_push),
                resume=True,
                watch_interval=interval,
            )
        )
        return

    # New refinement — require request or request-file
    request_text = ""
    request_file_path = None

    if args.request_file:
        parsed = parse_request_file(args.request_file)
        request_text = parsed["text"]
        request_file_path = args.request_file
    elif args.request:
        request_text = args.request
    else:
        parser.error("Provide --request TEXT or --request-file PATH")
        return

    if not request_text.strip():
        parser.error("Request text is empty")
        return

    asyncio.run(
        run_refinement(
            request_text,
            request_file=request_file_path,
            auto_push=bool(args.auto_push),
            watch_interval=interval,
        )
    )


if __name__ == "__main__":
    main()
