#!/bin/bash
#
# Slack Notification Hook
# Events:
#   UserPromptSubmit — 사용자 명령을 임시파일에 저장
#   Stop             — 작업 완료 알림 (명령 + 처리 요약)
#   Notification     — 결정 필요 알림
#
# 환경변수 SLACK_WEBHOOK_URL 필수.
#

if [[ -z "$SLACK_WEBHOOK_URL" ]]; then
  exit 0
fi

INPUT=$(cat)

HOOK_EVENT=$(echo "$INPUT" | python3 -c \
  "import sys,json; print(json.load(sys.stdin).get('hook_event_name',''))" \
  2>/dev/null || echo "")

WORKTREE=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
REPO=$(git remote get-url origin 2>/dev/null \
  | sed -E 's|\.git$||; s|.*[/:]([^/]+)$|\1|')
if [[ -z "$REPO" ]]; then
  REPO=$(basename "$(dirname "$(git rev-parse --git-common-dir 2>/dev/null)")" 2>/dev/null || echo "unknown")
fi
PROMPT_FILE="/tmp/claude-slack-prompt-${WORKTREE}.txt"
LOG_FILE="/tmp/claude-slack-notify-${WORKTREE}.log"

log_err() {
  printf '%s [event=%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$HOOK_EVENT" "$1" >> "$LOG_FILE" 2>/dev/null
}

# ── UserPromptSubmit: 사용자 명령 저장 ──
if [[ "$HOOK_EVENT" == "UserPromptSubmit" ]]; then
  echo "$INPUT" | python3 -c \
    "import sys,json; print(json.load(sys.stdin).get('prompt',''))" \
    2>/dev/null > "$PROMPT_FILE"
  exit 0
fi

# ── Stop: 작업 완료 (명령 + 요약) ──
if [[ "$HOOK_EVENT" == "Stop" ]]; then
  STOP_ACTIVE=$(echo "$INPUT" | python3 -c \
    "import sys,json; print(json.load(sys.stdin).get('stop_hook_active', False))" \
    2>/dev/null || echo "False")
  if [[ "$STOP_ACTIVE" == "True" ]]; then
    exit 0
  fi

  TRANSCRIPT=$(echo "$INPUT" | python3 -c \
    "import sys,json; print(json.load(sys.stdin).get('transcript_path',''))" \
    2>/dev/null || echo "")

  PAYLOAD=$(PROMPT_FILE="$PROMPT_FILE" TRANSCRIPT_PATH="$TRANSCRIPT" \
            WORKTREE="$WORKTREE" REPO="$REPO" \
    python3 <<'PYEOF' 2>>"$LOG_FILE"
import os, json, re

def safe_read(path, limit_bytes=8192):
    try:
        with open(path, 'rb') as f:
            data = f.read(limit_bytes)
        return data.decode('utf-8', errors='replace')
    except (FileNotFoundError, OSError):
        return ''

def sanitize(s):
    if not s:
        return ''
    return re.sub(r'[\ud800-\udfff]', '\ufffd', s)

prompt_file = os.environ.get('PROMPT_FILE', '')
prompt = sanitize(safe_read(prompt_file, 4096))
prompt = ' '.join(prompt.split())[:200]

transcript_path = os.environ.get('TRANSCRIPT_PATH', '')
summary = ''
if transcript_path and os.path.exists(transcript_path):
    entries = []
    try:
        with open(transcript_path, 'r', encoding='utf-8', errors='replace') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entries.append(json.loads(line))
                except Exception:
                    pass
    except OSError:
        entries = []
    last_user_idx = -1
    for i, e in enumerate(entries):
        if e.get('type') == 'user':
            last_user_idx = i
    texts = []
    for e in entries[last_user_idx + 1:]:
        if e.get('type') != 'assistant':
            continue
        msg = e.get('message') or {}
        content = msg.get('content') or []
        if isinstance(content, str):
            texts.append(content)
            continue
        for block in content:
            if isinstance(block, dict) and block.get('type') == 'text':
                t = (block.get('text') or '').strip()
                if t:
                    texts.append(t)
    substantial = [t for t in texts if len(t) > 20]
    chosen = substantial[-1] if substantial else (texts[-1] if texts else '')
    summary = sanitize(' '.join(chosen.split()))[:300]
if not summary:
    summary = '(요약 없음)'

worktree = sanitize(os.environ.get('WORKTREE', 'unknown'))
repo = sanitize(os.environ.get('REPO', ''))
header_id = repo + '/' + worktree if repo and repo != worktree else worktree
lines = [':white_check_mark: *작업 완료* — `' + header_id + '`']
if prompt:
    lines.append(':speech_balloon: ' + prompt)
lines.append(':memo: ' + summary)
payload = {'blocks': [{'type': 'section', 'text': {'type': 'mrkdwn', 'text': '\n'.join(lines)}}]}
print(json.dumps(payload, ensure_ascii=False))
PYEOF
)
  if [[ -z "$PAYLOAD" ]]; then
    log_err "payload assembly failed; sending fallback"
    PAYLOAD=$(WORKTREE="$WORKTREE" REPO="$REPO" python3 <<'PYEOF'
import os, json
worktree = os.environ.get('WORKTREE', 'unknown')
repo = os.environ.get('REPO', '')
header_id = repo + '/' + worktree if repo and repo != worktree else worktree
text = ':white_check_mark: *작업 완료* — `' + header_id + '` (payload assembly 실패; 로그 확인: /tmp/claude-slack-notify-' + worktree + '.log)'
print(json.dumps({'blocks': [{'type': 'section', 'text': {'type': 'mrkdwn', 'text': text}}]}, ensure_ascii=False))
PYEOF
)
  fi
  HTTP_CODE=$(printf '%s' "$PAYLOAD" | curl -s -o /dev/null -w '%{http_code}' \
    -X POST "$SLACK_WEBHOOK_URL" -H 'Content-type: application/json' -d @-)
  if [[ "$HTTP_CODE" != "200" ]]; then
    log_err "slack post failed http=$HTTP_CODE"
    echo "slack-notify: post failed http=$HTTP_CODE (see /tmp/claude-slack-notify-${WORKTREE}.log)" >&2
  fi

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

  PAYLOAD=$(PROMPT_FILE="$PROMPT_FILE" MESSAGE="$MESSAGE" WORKTREE="$WORKTREE" REPO="$REPO" NTYPE="$NTYPE" \
    python3 <<'PYEOF' 2>>"$LOG_FILE"
import os, json, re

def safe_read(path, limit_bytes=4096):
    try:
        with open(path, 'rb') as f:
            data = f.read(limit_bytes)
        return data.decode('utf-8', errors='replace')
    except (FileNotFoundError, OSError):
        return ''

def sanitize(s):
    if not s:
        return ''
    return re.sub(r'[\ud800-\udfff]', '\ufffd', s)

prompt = ' '.join(sanitize(safe_read(os.environ.get('PROMPT_FILE', ''))).split())[:200]
msg = sanitize(os.environ.get('MESSAGE', 'attention needed'))[:300]
worktree = sanitize(os.environ.get('WORKTREE', 'unknown'))
repo = sanitize(os.environ.get('REPO', ''))
header_id = repo + '/' + worktree if repo and repo != worktree else worktree
lines = [':bell: *결정 필요* — `' + header_id + '`']
if prompt:
    lines.append(':speech_balloon: ' + prompt)
lines.append(':point_right: ' + msg)
payload = {'blocks': [{'type': 'section', 'text': {'type': 'mrkdwn', 'text': '\n'.join(lines)}}]}
print(json.dumps(payload, ensure_ascii=False))
PYEOF
)
  if [[ -z "$PAYLOAD" ]]; then
    log_err "notification payload assembly failed; sending fallback"
    PAYLOAD=$(WORKTREE="$WORKTREE" REPO="$REPO" MESSAGE="$MESSAGE" python3 <<'PYEOF'
import os, json
worktree = os.environ.get('WORKTREE', 'unknown')
repo = os.environ.get('REPO', '')
header_id = repo + '/' + worktree if repo and repo != worktree else worktree
text = ':bell: *결정 필요* — `' + header_id + '` (payload assembly 실패)'
print(json.dumps({'blocks': [{'type': 'section', 'text': {'type': 'mrkdwn', 'text': text}}]}, ensure_ascii=False))
PYEOF
)
  fi
  HTTP_CODE=$(printf '%s' "$PAYLOAD" | curl -s -o /dev/null -w '%{http_code}' \
    -X POST "$SLACK_WEBHOOK_URL" -H 'Content-type: application/json' -d @-)
  if [[ "$HTTP_CODE" != "200" ]]; then
    log_err "notification slack post failed http=$HTTP_CODE"
    echo "slack-notify: notification post failed http=$HTTP_CODE (see /tmp/claude-slack-notify-${WORKTREE}.log)" >&2
  fi

  exit 0
fi

exit 0
