#!/usr/bin/env python3
"""SubagentStop hook: warn if QA has not been confirmed.

When a subagent finishes, checks whether QA has been run.
Outputs a warning but does NOT block (exit 0 always).
"""
import glob
import json
import os
import sys
from datetime import date


def main() -> None:
    repo_root = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())
    reports_dir = os.path.join(repo_root, "docs", "reports")

    # Check if any report exists with QA results
    all_reports = sorted(
        glob.glob(os.path.join(reports_dir, "*.md")),
        key=os.path.getmtime,
        reverse=True,
    )
    all_reports = [r for r in all_reports if not r.endswith("README.md")]

    qa_confirmed = False
    if all_reports:
        try:
            with open(all_reports[0], encoding="utf-8") as f:
                content = f.read()
            has_qa = "## QA" in content or "## qa" in content.lower()
            has_pass = any(
                marker in content.lower()
                for marker in ["pass", "complete", "approved"]
            )
            qa_confirmed = has_qa and has_pass
        except OSError:
            pass

    if not qa_confirmed:
        print(
            "WARNING: QA has not been confirmed yet. "
            "Run qa-reviewer or /feature-flow QA step before pushing."
        )

    sys.exit(0)


if __name__ == "__main__":
    main()
