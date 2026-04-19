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

  # 사용자 명령 읽기
  USER_PROMPT=""
  if [[ -f "$PROMPT_FILE" ]]; then
    USER_PROMPT=$(head -c 200 "$PROMPT_FILE" 2>/dev/null)
  fi

  # 처리 요약: transcript 에서 이번 턴 어시스턴트 응답 추출
  TRANSCRIPT=$(echo "$INPUT" | python3 -c \
    "import sys,json; print(json.load(sys.stdin).get('transcript_path',''))" \
    2>/dev/null || echo "")
  SUMMARY=""
  if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
    SUMMARY=$(TRANSCRIPT_PATH="$TRANSCRIPT" python3 <<'PYEOF' 2>/dev/null
import json, os
path = os.environ['TRANSCRIPT_PATH']
entries = []
with open(path, 'r', encoding='utf-8', errors='replace') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            entries.append(json.loads(line))
        except Exception:
            pass
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
chosen = ' '.join(chosen.split())
print(chosen[:300])
PYEOF
)
  fi
  if [[ -z "$SUMMARY" ]]; then
    SUMMARY="(요약 없음)"
  fi

  # 메시지 조립 — env 로 전달해 셸 보간 인젝션 방지
  PAYLOAD=$(USER_PROMPT="$USER_PROMPT" SUMMARY="$SUMMARY" WORKTREE="$WORKTREE" REPO="$REPO" \
    python3 <<'PYEOF' 2>>"$LOG_FILE"
import os, json
prompt = os.environ.get('USER_PROMPT', '')[:200]
summary = os.environ.get('SUMMARY', '')[:300]
worktree = os.environ.get('WORKTREE', 'unknown')
repo = os.environ.get('REPO', '')
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
    log_err "payload assembly failed"
    exit 0
  fi
  HTTP_CODE=$(printf '%s' "$PAYLOAD" | curl -s -o /dev/null -w '%{http_code}' \
    -X POST "$SLACK_WEBHOOK_URL" -H 'Content-type: application/json' -d @-)
  if [[ "$HTTP_CODE" != "200" ]]; then
    log_err "slack post failed http=$HTTP_CODE"
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

  # 사용자 명령 읽기
  USER_PROMPT=""
  if [[ -f "$PROMPT_FILE" ]]; then
    USER_PROMPT=$(head -c 200 "$PROMPT_FILE" 2>/dev/null)
  fi

  PAYLOAD=$(USER_PROMPT="$USER_PROMPT" MESSAGE="$MESSAGE" WORKTREE="$WORKTREE" REPO="$REPO" NTYPE="$NTYPE" \
    python3 <<'PYEOF' 2>>"$LOG_FILE"
import os, json
prompt = os.environ.get('USER_PROMPT', '')[:200]
msg = os.environ.get('MESSAGE', 'attention needed')[:300]
worktree = os.environ.get('WORKTREE', 'unknown')
repo = os.environ.get('REPO', '')
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
    log_err "notification payload assembly failed"
    exit 0
  fi
  HTTP_CODE=$(printf '%s' "$PAYLOAD" | curl -s -o /dev/null -w '%{http_code}' \
    -X POST "$SLACK_WEBHOOK_URL" -H 'Content-type: application/json' -d @-)
  if [[ "$HTTP_CODE" != "200" ]]; then
    log_err "notification slack post failed http=$HTTP_CODE"
  fi

  exit 0
fi

exit 0
