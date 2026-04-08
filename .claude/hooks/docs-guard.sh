#!/bin/bash
#
# PreToolUse Hook: Docs Guard
# Blocks Write/Edit to docs/ files (except docs/reports/)
# Exit codes: 0 = allowed, 2 = blocked
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

# Block all other docs/ modifications
if [[ "$REL_PATH" == docs/* ]]; then
  echo -e "${RED}BLOCKED: docs/ files are the Source of Truth and must not be modified.${NC}" >&2
  echo -e "${RED}File: $REL_PATH${NC}" >&2
  echo -e "${RED}If modification is necessary, get explicit user approval first.${NC}" >&2
  exit 2
fi

exit 0
