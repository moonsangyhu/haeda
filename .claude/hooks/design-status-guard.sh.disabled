#!/usr/bin/env python3
"""
PreToolUse Hook: Design Status Guard

Validates the `status` front-matter field when Write/Edit/NotebookEdit targets
docs/design/(specs|drafts)/*.md. Enforces:

- status is present and is one of: draft | ready | in-progress | implemented | dropped
- in design worktree (.design-worktree sentinel present): only draft / ready / dropped allowed
  (in-progress and implemented are feature-worktree-only transitions)

Exit codes: 0 = allowed, 2 = blocked
"""
import json
import os
import re
import sys

PROJECT_DIR = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
ALLOWED = {"draft", "ready", "in-progress", "implemented", "dropped"}
DESIGN_ROLE_ALLOWED = {"draft", "ready", "dropped"}

RED = "\033[0;31m"
NC = "\033[0m"


def block(msg: str, file_path: str) -> None:
    sys.stderr.write(f"{RED}BLOCKED (design-status-guard): {msg}{NC}\n")
    sys.stderr.write(f"{RED}File: {file_path}{NC}\n")
    sys.exit(2)


def read_file_safe(path: str) -> str:
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    except (FileNotFoundError, OSError):
        return ""


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    tool_name = data.get("tool_name", "")
    tool_input = data.get("tool_input") or {}
    file_path = tool_input.get("file_path") or ""
    if not file_path:
        sys.exit(0)

    rel = file_path
    prefix = PROJECT_DIR.rstrip("/") + "/"
    if file_path.startswith(prefix):
        rel = file_path[len(prefix):]

    m = re.match(r"^docs/design/(specs|drafts)/([^/]+\.md)$", rel)
    if not m:
        sys.exit(0)
    filename = m.group(2)
    if filename.startswith("TEMPLATE-"):
        sys.exit(0)

    if tool_name == "Write":
        post = tool_input.get("content") or ""
    elif tool_name == "Edit":
        old = tool_input.get("old_string") or ""
        new = tool_input.get("new_string") or ""
        replace_all = bool(tool_input.get("replace_all"))
        on_disk = read_file_safe(file_path)
        if not on_disk:
            post = new
        elif replace_all:
            post = on_disk.replace(old, new)
        else:
            idx = on_disk.find(old)
            if idx == -1:
                sys.exit(0)
            post = on_disk[:idx] + new + on_disk[idx + len(old):]
    else:
        sys.exit(0)

    fm = re.match(r"^---\s*\n(.*?)\n---\s*\n", post, re.DOTALL)
    if not fm:
        block("design spec must start with YAML front-matter (--- ... ---)", rel)
    body = fm.group(1)

    status_line = re.search(r"^status:\s*([^\s#]+)", body, re.MULTILINE)
    if not status_line:
        block("front-matter missing required 'status' field", rel)
    status = status_line.group(1).strip()

    if status not in ALLOWED:
        block(
            f"invalid status '{status}'. "
            "Allowed: draft | ready | in-progress | implemented | dropped",
            rel,
        )

    has_sentinel = os.path.isfile(os.path.join(PROJECT_DIR, ".design-worktree"))
    if has_sentinel and status not in DESIGN_ROLE_ALLOWED:
        block(
            f"design worktree cannot set status='{status}'. "
            "Only draft/ready/dropped are author-side; "
            "in-progress and implemented are feature-worktree-only transitions.",
            rel,
        )

    sys.exit(0)


if __name__ == "__main__":
    main()
