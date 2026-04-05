#!/usr/bin/env python3
"""Stop hook: warn (not block) if report or QA is missing.

Checks if the session produced a feature report with QA results.
Outputs a warning message but does NOT block (exit 0 always).
"""
import glob
import json
import os
import sys
from datetime import date


def main() -> None:
    repo_root = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())
    reports_dir = os.path.join(repo_root, "docs", "reports")

    warnings = []

    # Check for today's reports
    today = date.today().isoformat()
    pattern = os.path.join(reports_dir, f"{today}-*.md")
    today_reports = glob.glob(pattern)

    if not today_reports:
        all_reports = glob.glob(os.path.join(reports_dir, "*.md"))
        all_reports = [r for r in all_reports if not r.endswith("README.md")]
        if not all_reports:
            warnings.append(
                "WARNING: No feature report found in docs/reports/. "
                "If you worked on a feature, consider running /feature-flow first."
            )

    # Check latest report for QA
    all_reports = sorted(
        glob.glob(os.path.join(reports_dir, "*.md")),
        key=os.path.getmtime,
        reverse=True,
    )
    all_reports = [r for r in all_reports if not r.endswith("README.md")]

    if all_reports:
        try:
            with open(all_reports[0], encoding="utf-8") as f:
                content = f.read()
            has_qa = "## QA" in content or "## qa" in content.lower()
            if not has_qa:
                warnings.append(
                    f"WARNING: Latest report ({os.path.basename(all_reports[0])}) "
                    "has no QA results. Consider completing QA before ending the session."
                )
        except OSError:
            pass

    if warnings:
        print("\n".join(warnings))

    # Always allow stop (warning only)
    sys.exit(0)


if __name__ == "__main__":
    main()
