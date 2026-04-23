#!/bin/bash
#
# PreToolUse Hook: Docs Guard
#
# Purpose (post-AIDLC migration):
# - Block writes to docs/ARCHIVE/** (legacy source-of-truth, read-only reference)
# - Allow everything else; AIDLC's own approval gates govern aidlc-docs/
#
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

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
REL_PATH="${FILE_PATH#$PROJECT_DIR/}"

# BLOCK writes to legacy archive
if [[ "$REL_PATH" == docs/ARCHIVE/* ]]; then
  echo -e "${RED}BLOCKED: docs/ARCHIVE/** is read-only (legacy source-of-truth).${NC}" >&2
  echo -e "${RED}  Path: $REL_PATH${NC}" >&2
  echo -e "${RED}  If you need to update a requirement, edit aidlc-docs/inception/requirements/ instead.${NC}" >&2
  exit 2
fi

exit 0
