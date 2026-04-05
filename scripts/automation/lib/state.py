"""Compact JSON state management for slice automation runs.

Design: state files are SMALL. They contain status + file-path pointers only.
Long text (prompts, logs, summaries) lives in separate files referenced by path.
"""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


@dataclass
class TaskState:
    """Per-role task state (backend / frontend / qa). ~15 fields max."""

    status: str = "pending"  # pending | running | done | failed | skipped
    worktree_path: Optional[str] = None
    worktree_branch: Optional[str] = None
    prompt_file: Optional[str] = None
    log_file: Optional[str] = None
    result_summary_file: Optional[str] = None
    started_at: Optional[str] = None
    finished_at: Optional[str] = None
    exit_code: Optional[int] = None
    error: Optional[str] = None
    cost_usd: Optional[float] = None
    num_turns: Optional[int] = None

    def mark_running(self) -> None:
        self.status = "running"
        self.started_at = _now()

    def mark_done(self, exit_code: int = 0) -> None:
        self.status = "done" if exit_code == 0 else "failed"
        self.exit_code = exit_code
        self.finished_at = _now()

    def mark_failed(self, error: str) -> None:
        self.status = "failed"
        self.error = error
        self.finished_at = _now()

    def save(self, path: Path) -> None:
        path.write_text(json.dumps(asdict(self), indent=2, default=str) + "\n")

    @classmethod
    def load(cls, path: Path) -> TaskState:
        data = json.loads(path.read_text())
        return cls(**{k: v for k, v in data.items() if k in cls.__dataclass_fields__})


@dataclass
class RunState:
    """Top-level run state for a slice. Intentionally compact (~20 fields)."""

    slice_name: str = ""
    status: str = "pending"  # pending | plan | build | merge | qa | remediate | complete | failed
    phase: str = "plan"
    retry_count: int = 0
    qa_verdict: Optional[str] = None  # complete | partial | incomplete
    verify_status: Optional[str] = None  # passed | failed | skipped
    next_slice_name: Optional[str] = None

    # Pointer paths (relative to run dir)
    backend_task: str = "tasks/backend.json"
    frontend_task: str = "tasks/frontend.json"
    qa_task: str = "tasks/qa.json"
    summary_file: Optional[str] = None
    qa_summary_file: Optional[str] = None
    next_slice_file: Optional[str] = None

    started_at: Optional[str] = None
    finished_at: Optional[str] = None
    error: Optional[str] = None

    # Non-serialized
    _run_dir: Optional[Path] = field(default=None, repr=False)

    def __post_init__(self) -> None:
        if not self.started_at:
            self.started_at = _now()

    def save(self) -> None:
        if not self._run_dir:
            raise ValueError("RunState._run_dir not set")
        path = self._run_dir / "run.json"
        data = asdict(self)
        data.pop("_run_dir", None)
        path.write_text(json.dumps(data, indent=2, default=str) + "\n")

    @classmethod
    def load(cls, run_dir: Path) -> RunState:
        path = run_dir / "run.json"
        data = json.loads(path.read_text())
        data.pop("_run_dir", None)
        state = cls(**{k: v for k, v in data.items() if k in cls.__dataclass_fields__})
        state._run_dir = run_dir
        return state

    @classmethod
    def create(cls, slice_name: str, run_dir: Path) -> RunState:
        state = cls(slice_name=slice_name)
        state._run_dir = run_dir
        return state

    def get_task_state(self, role: str) -> TaskState:
        """Load task state for a role (backend/frontend/qa)."""
        task_file = getattr(self, f"{role}_task")
        path = self._run_dir / task_file
        if path.exists():
            return TaskState.load(path)
        return TaskState()

    def save_task_state(self, role: str, task: TaskState) -> None:
        task_file = getattr(self, f"{role}_task")
        task.save(self._run_dir / task_file)

    def mark_failed(self, error: str) -> None:
        self.status = "failed"
        self.phase = "failed"
        self.error = error
        self.finished_at = _now()
        self.save()

    def transition(self, phase: str) -> None:
        self.phase = phase
        self.status = phase
        self.save()
