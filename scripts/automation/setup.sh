#!/bin/bash
# Setup automation venv with Agent SDK (optional enhancement)
# Usage: bash scripts/automation/setup.sh

set -e

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VENV="$REPO_ROOT/.venv-automation"

echo "Creating venv at $VENV ..."
python3 -m venv "$VENV"

echo "Installing claude-agent-sdk ..."
"$VENV/bin/pip" install --quiet claude-agent-sdk

echo ""
echo "Setup complete!"
echo "Usage:"
echo "  PYTHON=$VENV/bin/python make slice-auto"
echo "  # or directly:"
echo "  $VENV/bin/python scripts/automation/run_slice.py --auto"
