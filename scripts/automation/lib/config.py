"""Paths and constants for slice automation."""

from pathlib import Path

# Repo root (scripts/automation/lib/config.py → 3 levels up)
REPO_ROOT = Path(__file__).resolve().parents[3]

# Source of truth docs
DOCS_DIR = REPO_ROOT / "docs"
DOC_PRD = DOCS_DIR / "prd.md"
DOC_API = DOCS_DIR / "api-contract.md"
DOC_DOMAIN = DOCS_DIR / "domain-model.md"
DOC_FLOWS = DOCS_DIR / "user-flows.md"

# Test reports
TEST_REPORTS_DIR = REPO_ROOT / "test-reports"

# Automation artifacts
AUTOMATION_DIR = REPO_ROOT / "automation"
RUNS_DIR = AUTOMATION_DIR / "runs"

# Worktree base
WORKTREE_BASE = REPO_ROOT / ".claude" / "worktrees"

# Claude invocation defaults
DEFAULT_MODEL = "sonnet"
DEFAULT_PERMISSION_MODE = "acceptEdits"
MAX_REMEDIATION_RETRIES = 1
MAX_CONTINUATION_RETRIES = 1  # max-turns continuation per task

# Phase-specific max turns (backend needs more: models + migrations + tests)
MAX_TURNS_PLAN = 15
MAX_TURNS_PLAN_CONTINUATION = 10
MAX_TURNS_BACKEND = 50
MAX_TURNS_FRONTEND = 30
MAX_TURNS_QA = 20
MAX_TURNS_REMEDIATE = 30
MAX_TURNS_CONTINUATION = 30  # continuation after max-turns hit

# Phase names
PHASE_PLAN = "plan"
PHASE_BUILD = "build"
PHASE_MERGE = "merge"
PHASE_QA = "qa"
PHASE_REMEDIATE = "remediate"
PHASE_VERIFY = "verify"  # post-QA: test-report + local stack + smoke
PHASE_COMPLETE = "complete"
PHASE_FAILED = "failed"

# Max turns for verify phase (lightweight: just run docker + smoke)
MAX_TURNS_VERIFY = 15

# Refinement pipeline (lighter than slice phases)
MAX_TURNS_ANALYZE = 10
MAX_TURNS_IMPLEMENT = 30
MAX_TURNS_VERIFY_REFINE = 15

# Task statuses
STATUS_PENDING = "pending"
STATUS_RUNNING = "running"
STATUS_DONE = "done"
STATUS_FAILED = "failed"
STATUS_SKIPPED = "skipped"


def run_dir(slice_name: str) -> Path:
    return RUNS_DIR / slice_name


def ensure_run_dirs(slice_name: str) -> Path:
    """Create and return the run directory structure."""
    rd = run_dir(slice_name)
    (rd / "tasks").mkdir(parents=True, exist_ok=True)
    (rd / "prompts").mkdir(parents=True, exist_ok=True)
    (rd / "results").mkdir(parents=True, exist_ok=True)
    (rd / "logs").mkdir(parents=True, exist_ok=True)
    return rd
