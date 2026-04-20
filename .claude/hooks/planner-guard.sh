#!/bin/bash
#
# PreToolUse Hook: Planner Guard
# Blocks Write/Edit/NotebookEdit to anything outside docs/planning/ when the
# .planner-worktree sentinel is present at the repo root.
# Exit codes: 0 = allowed, 2 = blocked
#

RED='\033[0;31m'
NC='\033[0m'

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# If sentinel is absent, this worktree is not a planner — allow everything.
if [[ ! -f "$PROJECT_DIR/.planner-worktree" ]]; then
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

if [[ "$REL_PATH" == docs/planning/* ]] || [[ "$REL_PATH" == docs/reports/* ]]; then
  exit 0
fi

echo -e "${RED}BLOCKED: planner worktree may only edit docs/planning/** (task reports in docs/reports/** also allowed)${NC}" >&2
echo -e "${RED}File: $REL_PATH${NC}" >&2
echo -e "${RED}Config/rule/skill edits belong in a claude-role worktree; code edits in backend/front worktrees.${NC}" >&2
exit 2
