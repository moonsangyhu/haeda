# 슬랙 hook 한글 surrogate UnicodeEncodeError 수정

| 항목 | 값 |
|------|---|
| Date | 2026-04-19 |
| Worktree (수행) | `.claude/worktrees/claude` |
| Worktree (영향) | 모든 워크트리 (slack-notify.sh 공통 사용) |
| Role | claude |

## Request

> 왜 또 슬랙 알람이 안 왔냐. 강제성이 너무 부족항거 아냐?

## Root cause

`slack-notify.sh` 의 Stop·Notification 분기에서 사용자 명령을 가져올 때 `head -c 200 "$PROMPT_FILE"` 로 byte 단위 truncation 을 했다. 한글 한 글자는 UTF-8 에서 3 bytes 라 200 byte 경계가 글자 중간에 떨어지면 마지막 1–2 bytes 가 invalid UTF-8 sequence 가 된다.

이 잘린 bytes 가 `USER_PROMPT="$USER_PROMPT"` 로 환경변수가 되고, Python `os.environ.get(...)` 이 surrogateescape 로 디코드해 `\udceb` 같은 lone surrogate 가 string 안에 들어간다. 그 다음 `json.dumps(..., ensure_ascii=False)` 가 surrogate 인코딩에서 `UnicodeEncodeError` 로 죽고, payload 가 빈 문자열이 되어 hook 이 silently `exit 0` 하면서 Slack 으로 아무것도 보내지 않는다.

`/tmp/claude-slack-notify-claude.log` 에 다음 같은 traceback 이 누적되고 있었다:
```
UnicodeEncodeError: 'utf-8' codec can't encode character '\udceb' in position 197: surrogates not allowed
[event=Stop] payload assembly failed
[event=Notification] notification payload assembly failed
```

이전 commit `c916c3f fix(claude): 슬랙 hook 셸 인젝션 + 무음 실패 수정` 은 별개 (셸 인젝션) 문제만 고쳤고 byte-truncation 문제는 남아있었다.

## Actions

`.claude/hooks/slack-notify.sh` 두 분기 (Stop, Notification) 동시 수정:

1. **Byte-truncation 제거**: shell `head -c 200` 으로 PROMPT_FILE 을 자르지 않는다. 대신 Python 안에서 `open(path, 'rb').read(8192)` 로 충분히 긴 bytes 를 읽고 `decode('utf-8', errors='replace')` 한 뒤 character 단위로 `[:200]` 슬라이스. byte 경계 문제 원천 제거.

2. **방어적 surrogate sanitizer**: 모든 외부 문자열 (PROMPT, SUMMARY, MESSAGE, WORKTREE, REPO) 에 `re.sub(r'[\ud800-\udfff]', '\ufffd', s)` 적용. 향후 다른 경로로 surrogate 가 흘러들어와도 `json.dumps` 가 안 죽는다.

3. **Fallback payload**: 그래도 payload 조립이 실패하면 빈 문자열 대신 `"작업 완료 (payload assembly 실패; 로그 확인: /tmp/...)"` 한 줄짜리 메시지를 fallback 으로 보낸다. **Slack 채널이 침묵하지 않는다.**

4. **Stderr 가시성 강화**: `curl` post 가 200 이 아니면 stderr 에 `slack-notify: post failed http=$HTTP_CODE (see /tmp/...)` 출력. Stop/Notification hook 의 stderr 는 사용자 transcript 에 노출된다.

## Verification

### 회귀 테스트 (이전 패턴 재현 → 크래시 없는지 확인)

```bash
# 390 bytes 한글 prompt 를 PROMPT_FILE 에 저장 (byte 경계가 한글 중간에 떨어지는 길이)
LONG_PROMPT='앞으로 디자인 워크트리에서 ... (실제 사용자 이전 메시지 ~390 bytes)'
printf '%s' "$LONG_PROMPT" > /tmp/claude-slack-prompt-claude.txt

echo '{"hook_event_name":"Stop","transcript_path":"","stop_hook_active":false}' \
  | SLACK_WEBHOOK_URL=https://example.invalid/test ./slack-notify.sh
```

결과: `slack-notify: post failed http=000 (...)` stderr 출력 + exit 0. **Python 크래시 없음.** 로그에 새로운 traceback 없음. (post 자체는 invalid URL 이라 실패하는 게 정상.)

### 실 webhook post 검증

같은 prompt 로 실 SLACK_WEBHOOK_URL 사용:

```
=== Real Slack post test ===
exit=0
---log tail---
(traceback 없음, 새 항목 없음)
```

stderr 무출력 + exit 0 + 로그 새 항목 없음 = post 성공. Slack 채널에 메시지 도달 확인.

## Follow-ups

- `/tmp/claude-slack-notify-*.log` 누적 traceback 은 자연 만료 (재부팅·`/tmp` 정리). 별도 로그 rotation 필요시 follow-up.
- 다른 hook (push-gate.py 등) 에 비슷한 byte-truncation 패턴이 있는지 audit 가능 — 현재 시점에서는 slack-notify.sh 만 외부 텍스트를 truncate 하는 위치였다.
- 다른 워크트리 기존 세션은 이번 push 가 머지된 후 새 세션에서 hook 이 갱신된다 (`.claude/rules/claude-config-sync.md` §4).

## Related

- 이전 시도: `docs/reports/2026-04-19-claude-slack-notify-injection-fix.md` (셸 인젝션, 별개 문제)
- 이전 시도: `docs/reports/2026-04-19-claude-slack-summary-from-transcript.md`
- 이전 시도: `docs/reports/2026-04-19-claude-slack-notify-repo-name.md`
- Hook: `.claude/hooks/slack-notify.sh`
