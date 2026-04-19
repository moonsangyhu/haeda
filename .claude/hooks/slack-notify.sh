#!/bin/bash
#
# Slack Notification Hook
# Events: Stop (작업 완료), Notification (결정 필요)
#
# 환경변수 SLACK_WEBHOOK_URL 필수.
# 설정: ~/.zshrc 또는 ~/.zprofile 에 export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
#

# Webhook URL 미설정 시 조용히 종료
if [[ -z "$SLACK_WEBHOOK_URL" ]]; then
  exit 0
fi

INPUT=$(cat)

HOOK_EVENT=$(echo "$INPUT" | python3 -c \
  "import sys,json; print(json.load(sys.stdin).get('hook_event_name',''))" \
  2>/dev/null || echo "")

# 워크트리 이름 추출
WORKTREE=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")

# ── Stop: 작업 완료 ──
if [[ "$HOOK_EVENT" == "Stop" ]]; then
  # 무한루프 방지: stop_hook_active 체크
  STOP_ACTIVE=$(echo "$INPUT" | python3 -c \
    "import sys,json; print(json.load(sys.stdin).get('stop_hook_active', False))" \
    2>/dev/null || echo "False")
  if [[ "$STOP_ACTIVE" == "True" ]]; then
    exit 0
  fi

  PAYLOAD=$(python3 -c "
import json, sys
payload = {
    'blocks': [
        {
            'type': 'section',
            'text': {
                'type': 'mrkdwn',
                'text': ':white_check_mark: *작업 완료*\n워크트리: \`$WORKTREE\`'
            }
        }
    ]
}
print(json.dumps(payload))
")

  curl -s -X POST "$SLACK_WEBHOOK_URL" \
    -H 'Content-type: application/json' \
    -d "$PAYLOAD" > /dev/null 2>&1 &

  exit 0
fi

# ── Notification: 결정 필요 ──
if [[ "$HOOK_EVENT" == "Notification" ]]; then
  NTYPE=$(echo "$INPUT" | python3 -c \
    "import sys,json; print(json.load(sys.stdin).get('notification_type',''))" \
    2>/dev/null || echo "")
  MESSAGE=$(echo "$INPUT" | python3 -c \
    "import sys,json; print(json.load(sys.stdin).get('message','attention needed'))" \
    2>/dev/null || echo "attention needed")

  PAYLOAD=$(python3 -c "
import json, sys
msg = '''$MESSAGE'''.replace(\"'\", \"\\\\'\")
payload = {
    'blocks': [
        {
            'type': 'section',
            'text': {
                'type': 'mrkdwn',
                'text': ':bell: *결정 필요*\n워크트리: \`$WORKTREE\`\n유형: \`$NTYPE\`\n> ' + msg
            }
        }
    ]
}
print(json.dumps(payload))
")

  curl -s -X POST "$SLACK_WEBHOOK_URL" \
    -H 'Content-type: application/json' \
    -d "$PAYLOAD" > /dev/null 2>&1 &

  exit 0
fi

exit 0
