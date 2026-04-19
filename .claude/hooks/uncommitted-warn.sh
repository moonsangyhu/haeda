#!/usr/bin/env bash
# Stop hook: warn about uncommitted changes when session ends.
# Prevents silent loss of work from interrupted feature-flow pipelines.

cd "$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

STAGED=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
UNSTAGED=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')

if [ "$STAGED" -gt 0 ] || [ "$UNSTAGED" -gt 0 ]; then
  echo "⚠️ 미커밋 변경 감지: staged ${STAGED}개, unstaged ${UNSTAGED}개"
  echo "   다음 세션에서 /commit 또는 feature-flow 재개 필요"
fi
