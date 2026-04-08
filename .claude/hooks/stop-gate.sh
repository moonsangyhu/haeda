#!/bin/bash
#
# Stop Hook: session end warnings
# Advisory only — never blocks (exit 0 always)
#

YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# --- Check 1: Uncommitted changes ---
COUNT=$(( $(git diff --name-only 2>/dev/null | wc -l) + $(git diff --cached --name-only 2>/dev/null | wc -l) ))

if [[ "$COUNT" -gt 0 ]]; then
  echo -e "${YELLOW}WARNING: $COUNT uncommitted change(s)${NC}" >&2
  echo -e "${YELLOW}Branch: $(git branch --show-current 2>/dev/null)${NC}" >&2
fi

# --- Check 2: Feature report existence ---
REPORTS_DIR="$PROJECT_DIR/docs/reports"
TODAY=$(date +%Y-%m-%d)

if [[ -d "$REPORTS_DIR" ]]; then
  TODAY_REPORTS=$(find "$REPORTS_DIR" -name "${TODAY}-*.md" 2>/dev/null | wc -l)
  if [[ "$TODAY_REPORTS" -eq 0 ]]; then
    ALL_REPORTS=$(find "$REPORTS_DIR" -name "*.md" ! -name "README.md" 2>/dev/null | wc -l)
    if [[ "$ALL_REPORTS" -eq 0 ]]; then
      echo -e "${YELLOW}WARNING: No feature report in docs/reports/.${NC}" >&2
      echo -e "${CYAN}Run /feature-flow to generate a report before pushing.${NC}" >&2
    fi
  fi

  # --- Check 3: QA results in latest report ---
  LATEST=$(find "$REPORTS_DIR" -name "*.md" ! -name "README.md" -print 2>/dev/null | sort -r | head -1)
  if [[ -n "$LATEST" ]]; then
    if ! grep -qi "## QA" "$LATEST" 2>/dev/null; then
      echo -e "${YELLOW}WARNING: Latest report ($(basename "$LATEST")) has no QA results.${NC}" >&2
    fi
  fi
fi

exit 0
