#!/bin/bash
#
# PreToolUse Hook: Design Guard
# Blocks Write/Edit/NotebookEdit to anything outside docs/design/ when the
# .design-worktree sentinel is present at the repo root.
# Exit codes: 0 = allowed, 2 = blocked
#

RED='\033[0;31m'
NC='\033[0m'

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# If sentinel is absent, this worktree is not a designer — allow everything.
if [[ ! -f "$PROJECT_DIR/.design-worktree" ]]; then
  exit 0
fi

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" \
  2>/dev/null || echo "")

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

REL_PATH="${FILE_PATH#$PROJECT_DIR/}"

if [[ "$REL_PATH" == docs/design/* ]]; then
  exit 0
fi

echo -e "${RED}BLOCKED: design worktree may only edit docs/design/**${NC}" >&2
echo -e "${RED}File: $REL_PATH${NC}" >&2
echo -e "${RED}Code edits belong in feature worktree (or backend/front split worktrees). Config/rule edits in claude worktree.${NC}" >&2
exit 2
