#!/usr/bin/env python3
"""PreToolUse hook: block git push unless report + QA conditions are met.

Reads tool input from stdin (JSON). Checks:
1. Is this a git push command?
2. Does a docs/reports/*.md file exist for today?
3. Does the report contain a QA result section with passing verdict?

Exit 0 = allow, exit 2 = block with reason on stdout.
"""
import glob
import json
import os
import sys
from datetime import date


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    tool_input = data.get("tool_input", {})
    command = tool_input.get("command", "")

    # Only gate actual git push commands (not commit messages that mention "git push")
    # Strip the command to its core: must start with "git push" or "git push" after && / ;
    stripped = command.strip()
    is_push = False
    for part in stripped.replace("&&", ";").split(";"):
        part = part.strip()
        if part.startswith("git push"):
            is_push = True
            break

    if not is_push:
        sys.exit(0)

    repo_root = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())

    # Skip gate for non-feature commits (infra, config, docs-only).
    # Check if ALL commits since remote are in non-feature paths.
    import subprocess

    diff_result = subprocess.run(
        ["git", "diff", "--name-only", "@{u}..HEAD"],
        capture_output=True,
        text=True,
        cwd=repo_root,
    )
    if diff_result.returncode == 0 and diff_result.stdout.strip():
        changed = [f.strip() for f in diff_result.stdout.strip().split("\n") if f.strip()]
        _NON_FEATURE_PREFIXES = (".claude/", "docs/reports/", "scripts/", "test-reports/", "Makefile", "CLAUDE.md")
        all_infra = all(
            any(f.startswith(p) or f == p for p in _NON_FEATURE_PREFIXES)
            for f in changed
        )
        if all_infra:
            sys.exit(0)  # Infra-only push, no report needed
    reports_dir = os.path.join(repo_root, "docs", "reports")

    # Check 1: Any report file exists for today
    today = date.today().isoformat()  # YYYY-MM-DD
    pattern = os.path.join(reports_dir, f"{today}-*.md")
    today_reports = glob.glob(pattern)

    if not today_reports:
        # Also check for any recent report (not just today)
        all_reports = glob.glob(os.path.join(reports_dir, "*.md"))
        # Exclude README.md
        all_reports = [r for r in all_reports if not r.endswith("README.md")]
        if not all_reports:
            print(
                "BLOCKED: git push requires a feature report in docs/reports/.\n"
                "Run /feature-flow to generate a report before pushing.",
                file=sys.stderr,
            )
            sys.exit(2)

    # Check 2: Most recent report has QA result
    all_reports = sorted(
        glob.glob(os.path.join(reports_dir, "*.md")),
        key=os.path.getmtime,
        reverse=True,
    )
    all_reports = [r for r in all_reports if not r.endswith("README.md")]

    if not all_reports:
        print(
            "BLOCKED: No feature reports found in docs/reports/.\n"
            "Run /feature-flow to complete the workflow before pushing.",
            file=sys.stderr,
        )
        sys.exit(2)

    latest_report = all_reports[0]
    try:
        with open(latest_report, encoding="utf-8") as f:
            content = f.read()
    except OSError:
        sys.exit(0)  # Can't read? Don't block.

    # Check for QA section with pass indicator
    has_qa_section = "## QA" in content or "## qa" in content.lower()
    has_pass = any(
        marker in content.lower()
        for marker in ["pass", "complete", "approved", "verdict: complete"]
    )

    if not has_qa_section:
        print(
            f"BLOCKED: Report {os.path.basename(latest_report)} has no QA results section.\n"
            "Complete QA review before pushing.",
            file=sys.stderr,
        )
        sys.exit(2)

    if not has_pass:
        print(
            f"BLOCKED: Report {os.path.basename(latest_report)} QA did not pass.\n"
            "Fix issues and re-run QA before pushing.",
            file=sys.stderr,
        )
        sys.exit(2)

    # All checks passed
    sys.exit(0)


if __name__ == "__main__":
    main()
