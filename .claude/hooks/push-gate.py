#!/usr/bin/env python3
"""PreToolUse hook: gate push/merge commands on AIDLC approval evidence.

Post-AIDLC migration rules:

1. Block legacy direct push to main (`git push origin HEAD:main`).
2. For `gh pr merge` or feature pushes that touch app/ or server/, require
   `aidlc-docs/audit.md` to exist AND contain at least one recent entry
   with "Approved" in an AI Response or stage-completion context.
3. Infra-only pushes (.claude/, CLAUDE.md, docs/, aidlc-docs/, scripts/,
   .aidlc-rule-details/) are allowed without audit evidence — these are
   configuration / documentation changes that AIDLC itself does not gate.

Exit 0 = allow, exit 2 = block with reason on stderr.
"""
import json
import os
import subprocess
import sys


_INFRA_PREFIXES = (
    ".claude/",
    ".aidlc-rule-details/",
    "aidlc-docs/",
    "docs/",
    "scripts/",
    "Makefile",
    "CLAUDE.md",
    "README.md",
    ".gitignore",
)


def _is_gated_command(command: str) -> bool:
    stripped = command.strip()
    for part in stripped.replace("&&", ";").split(";"):
        part = part.strip()
        if part.startswith("gh pr merge"):
            return True
        if part.startswith("git push") and "HEAD:main" in part:
            return True
    return False


def _is_direct_main_push(command: str) -> bool:
    stripped = command.strip()
    for part in stripped.replace("&&", ";").split(";"):
        part = part.strip()
        if part.startswith("git push") and "HEAD:main" in part:
            return True
    return False


def _infra_only_changes(repo_root: str) -> bool:
    """Return True if all commits since upstream touch only infra paths."""
    diff_result = subprocess.run(
        ["git", "diff", "--name-only", "@{u}..HEAD"],
        capture_output=True,
        text=True,
        cwd=repo_root,
    )
    if diff_result.returncode != 0 or not diff_result.stdout.strip():
        return False
    changed = [f.strip() for f in diff_result.stdout.strip().split("\n") if f.strip()]
    return all(
        any(f == p or f.startswith(p) for p in _INFRA_PREFIXES)
        for f in changed
    )


def _audit_has_recent_approval(repo_root: str) -> bool:
    audit_path = os.path.join(repo_root, "aidlc-docs", "audit.md")
    if not os.path.isfile(audit_path):
        return False
    try:
        with open(audit_path, encoding="utf-8") as fh:
            content = fh.read()
    except OSError:
        return False
    # Accept any sign of explicit approval from the user via AIDLC's
    # "Wait for Explicit Approval" flow.
    markers = (
        "Approved by user",
        "approved by user",
        "Continue to Next Stage",
        '[Answer]: approve',
        "User Input: \"approve\"",
        'approved"',
    )
    return any(m in content for m in markers)


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    command = (data.get("tool_input") or {}).get("command", "")

    if not _is_gated_command(command):
        sys.exit(0)

    # Hard-block legacy direct-to-main push regardless of content.
    if _is_direct_main_push(command):
        print(
            "BLOCKED: Direct `git push origin HEAD:main` is forbidden.\n"
            "Use `gh pr create` + `gh pr merge` via the PR flow instead.",
            file=sys.stderr,
        )
        sys.exit(2)

    repo_root = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())

    # Infra-only PR merges skip the AIDLC audit check.
    if _infra_only_changes(repo_root):
        sys.exit(0)

    # Feature change: require audit evidence of AIDLC approval.
    if _audit_has_recent_approval(repo_root):
        sys.exit(0)

    print(
        "BLOCKED: `gh pr merge` requires AIDLC approval evidence in "
        "aidlc-docs/audit.md.\n"
        "Drive the change through the AIDLC workflow (`Using AI-DLC, ...`) "
        "and obtain explicit stage approvals before merging.",
        file=sys.stderr,
    )
    sys.exit(2)


if __name__ == "__main__":
    main()
