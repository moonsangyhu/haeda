#!/bin/bash
#
# PreToolUse Hook: Docs Guard
# Warns on Write/Edit to docs/ source-of-truth files (non-blocking)
# Exit codes: 0 = allowed (always)
#

RED='\033[0;31m'
NC='\033[0m'

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" \
  2>/dev/null || echo "")

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Resolve to relative path from project root
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
REL_PATH="${FILE_PATH#$PROJECT_DIR/}"

# Allow docs/reports/ (auto-generated reports)
if [[ "$REL_PATH" == docs/reports/* ]]; then
  exit 0
fi

# Allow docs/planning/ (idea bank — shared between planner and feature worktrees)
if [[ "$REL_PATH" == docs/planning/* ]]; then
  exit 0
fi

# Allow docs/design/ (design specs — produced by design worktree)
if [[ "$REL_PATH" == docs/design/* ]]; then
  exit 0
fi

# Warn (non-blocking) for source-of-truth docs modifications
if [[ "$REL_PATH" == docs/* ]]; then
  YELLOW='\033[0;33m'
  echo -e "${YELLOW}NOTE: Modifying source-of-truth doc: $REL_PATH${NC}" >&2
  exit 0
fi

exit 0
