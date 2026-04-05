#!/usr/bin/env python3
"""TaskCompleted / TeammateIdle hook: cross-layer quality gate.

For cross-layer work (both app/ and server/ modified), ensures:
1. Both frontend and backend tests pass before declaring complete.
2. When a teammate becomes idle, checks if the other layer's work is done.

Reads event data from stdin. Outputs warnings (does not block).
"""
import json
import os
import subprocess
import sys


def get_changed_files(repo_root: str) -> list[str]:
    """Get list of changed files from git status."""
    try:
        result = subprocess.run(
            ["git", "status", "--porcelain"],
            capture_output=True,
            text=True,
            cwd=repo_root,
        )
        files = []
        for line in result.stdout.strip().split("\n"):
            line = line.strip()
            if line:
                path = line[3:].split(" -> ")[-1]
                files.append(path)
        return files
    except OSError:
        return []


def is_cross_layer(files: list[str]) -> bool:
    """Check if changes span both app/ and server/."""
    has_app = any(f.startswith("app/") for f in files)
    has_server = any(f.startswith("server/") for f in files)
    return has_app and has_server


def check_tests(repo_root: str, layer: str) -> tuple[bool, str]:
    """Run tests for a layer. Returns (passed, summary)."""
    if layer == "frontend":
        cmd = ["flutter", "test"]
        cwd = os.path.join(repo_root, "app")
    else:
        cmd = ["uv", "run", "pytest", "-v", "--tb=short"]
        cwd = os.path.join(repo_root, "server")

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=cwd,
            timeout=120,
        )
        passed = result.returncode == 0
        # Extract last few lines as summary
        lines = result.stdout.strip().split("\n")
        summary = lines[-1] if lines else "no output"
        return passed, summary
    except (OSError, subprocess.TimeoutExpired) as e:
        return False, str(e)


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        data = {}

    repo_root = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())
    changed = get_changed_files(repo_root)

    if not is_cross_layer(changed):
        # Not cross-layer work, no extra gates needed
        sys.exit(0)

    warnings = []

    # For cross-layer work, check both test suites
    app_files = [f for f in changed if f.startswith("app/")]
    server_files = [f for f in changed if f.startswith("server/")]

    if app_files:
        passed, summary = check_tests(repo_root, "frontend")
        if not passed:
            warnings.append(f"CROSS-LAYER GATE: Frontend tests failing — {summary}")

    if server_files:
        passed, summary = check_tests(repo_root, "backend")
        if not passed:
            warnings.append(f"CROSS-LAYER GATE: Backend tests failing — {summary}")

    if warnings:
        print("\n".join(warnings))
        print(
            "\nBoth frontend and backend tests must pass for cross-layer work. "
            "Fix failing tests before proceeding."
        )

    sys.exit(0)


if __name__ == "__main__":
    main()
