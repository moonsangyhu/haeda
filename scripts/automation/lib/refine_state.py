"""Compact JSON state for refinement pipeline runs.

Same design as state.py: status + file-path pointers only.
Long text (prompts, logs, reports) in separate files referenced by path.
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
class RefineState:
    """Top-level run state for a refinement. Intentionally compact."""

    run_id: str = ""
    status: str = "pending"  # pending|analyze|implement|verify|report|commit|push|complete|failed
    phase: str = "analyze"

    # Request
    request_text: str = ""
    request_file: Optional[str] = None

    # Analysis (pointer to results/analysis.json)
    affected_area: Optional[str] = None  # frontend|backend|both
    analysis_file: Optional[str] = None

    # Options
    auto_push: bool = False

    # Implementation
    retry_count: int = 0

    # Verify
    verify_verdict: Optional[str] = None  # passed|failed
    tests_backend: Optional[str] = None
    tests_frontend: Optional[str] = None

    # Commit / push
    commit_hash: Optional[str] = None
    push_status: str = "pending"  # pending|pushed|skipped|failed

    # Report
    report_file: Optional[str] = None

    # Meta
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
            raise ValueError("RefineState._run_dir not set")
        data = asdict(self)
        data.pop("_run_dir", None)
        (self._run_dir / "run.json").write_text(
            json.dumps(data, indent=2, default=str) + "\n"
        )

    @classmethod
    def load(cls, run_dir: Path) -> RefineState:
        data = json.loads((run_dir / "run.json").read_text())
        data.pop("_run_dir", None)
        state = cls(**{k: v for k, v in data.items() if k in cls.__dataclass_fields__})
        state._run_dir = run_dir
        return state

    @classmethod
    def create(cls, run_id: str, run_dir: Path, **kwargs) -> RefineState:
        state = cls(run_id=run_id, **kwargs)
        state._run_dir = run_dir
        return state

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
