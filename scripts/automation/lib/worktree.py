"""Git worktree operations for parallel backend/frontend execution."""

from __future__ import annotations

import logging
import subprocess
from pathlib import Path

from .config import REPO_ROOT, WORKTREE_BASE

log = logging.getLogger(__name__)


def _run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    log.debug("$ %s", " ".join(cmd))
    return subprocess.run(cmd, capture_output=True, text=True, cwd=str(REPO_ROOT), **kwargs)


def create_worktree(slice_name: str, role: str) -> tuple[Path, str]:
    """Create a git worktree for a role. Returns (worktree_path, branch_name)."""
    branch = f"auto/{slice_name}-{role}"
    wt_path = WORKTREE_BASE / f"{slice_name}-{role}"

    if wt_path.exists():
        log.info("Worktree already exists: %s", wt_path)
        return wt_path, branch

    WORKTREE_BASE.mkdir(parents=True, exist_ok=True)

    # Create branch from current HEAD
    _run(["git", "branch", "-D", branch], check=False)
    result = _run(["git", "worktree", "add", "-b", branch, str(wt_path)])
    if result.returncode != 0:
        raise RuntimeError(f"Failed to create worktree: {result.stderr.strip()}")

    log.info("Created worktree: %s (branch: %s)", wt_path, branch)
    return wt_path, branch


def merge_worktree(branch: str) -> bool:
    """Merge a worktree branch into the current branch. Returns success."""
    result = _run(["git", "merge", branch, "--no-edit"])
    if result.returncode != 0:
        log.error("Merge failed for %s: %s", branch, result.stderr.strip())
        return False
    log.info("Merged branch: %s", branch)
    return True


def cleanup_worktree(slice_name: str, role: str) -> None:
    """Remove a worktree and its branch."""
    wt_path = WORKTREE_BASE / f"{slice_name}-{role}"
    branch = f"auto/{slice_name}-{role}"

    if wt_path.exists():
        _run(["git", "worktree", "remove", str(wt_path), "--force"])
        log.info("Removed worktree: %s", wt_path)

    _run(["git", "branch", "-D", branch])


def cleanup_all(slice_name: str) -> None:
    """Clean up all worktrees for a slice."""
    for role in ("backend", "frontend"):
        cleanup_worktree(slice_name, role)


def commit_and_push(slice_name: str) -> bool:
    """Stage all changes, commit, and push for a completed slice.

    Returns True on success. Skips if nothing to commit.
    """
    # Check for uncommitted changes
    status = _run(["git", "status", "--porcelain"])
    if not status.stdout.strip():
        log.info("Nothing to commit for %s", slice_name)
        return True

    # Stage all tracked + new files (respects .gitignore)
    result = _run(["git", "add", "-A"])
    if result.returncode != 0:
        log.error("git add failed: %s", result.stderr.strip())
        return False

    # Commit
    msg = f"feat: implement {slice_name}\n\nAutomated slice implementation via scripts/automation.\n\nCo-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
    result = _run(["git", "commit", "-m", msg])
    if result.returncode != 0:
        log.error("git commit failed: %s", result.stderr.strip())
        return False
    log.info("Committed: %s", result.stdout.strip().split("\n")[0])

    # Push
    result = _run(["git", "push"])
    if result.returncode != 0:
        log.error("git push failed: %s", result.stderr.strip())
        return False
    log.info("Pushed to remote")

    return True
