# Slack hook 셸 보간 인젝션 버그 수정 + 실패 로깅

- **Date**: 2026-04-19
- **Worktree (수행)**: `.claude/worktrees/claude`
- **Worktree (영향)**: 모든 워크트리
- **Role**: claude

## Request

> 일단 방금 작업 슬랙 메시지 안 왔어. 왜 그랬는지 확인해서 이런 케이스도 슬랙 알람 와야 해

직전 turn (transcript 기반 SUMMARY 도입) 의 Stop 훅 알림이 슬랙에 도착하지 않은 사용자 보고. 동일 케이스에서 알림이 보장되도록 수정.

## Root cause / Context

이전 hook 의 메시지 조립부는 셸 변수 보간으로 SUMMARY/USER_PROMPT 값을 python 소스 안에 직접 박아 넣었다.

```bash
python3 -c "
prompt = '''${USER_PROMPT}'''.replace(...)
summary = '''${SUMMARY}'''.replace(...)
"
```

직전 turn 의 wrap-up 텍스트에는 백틱(`` ` ``) 과 달러 기호(`$`) 가 포함됐다(예: `` `:memo:` `` 인용, PR 번호 표기 등). 이 값이 `python3 -c "..."` 의 더블쿼트 안으로 들어가면서 **셸이 백틱을 명령 치환으로 해석**, python 호출 자체가 실패했다. `2>/dev/null &` 로 stderr 무시 + 백그라운드 실행이라 실패가 사용자에게 노출되지 않았다.

## Actions

`.claude/hooks/slack-notify.sh` 전반 수정:

1. **Stop / Notification 분기 메시지 조립** 을 `python3 -c "...${VAR}..."` 셸 보간 → `VAR=... python3 <<'PYEOF'` 환경변수 + single-quoted heredoc 로 교체. 사용자 입력이 python 소스 텍스트로 흘러들어가지 않으므로 backtick·`$`·따옴표 모두 안전.
2. **백그라운드 실행 제거**. `python3 ... | curl ... &` → `PAYLOAD=$(python3 ...)` 후 동기 curl. payload 조립 실패와 HTTP 비정상 응답을 즉시 캡처.
3. **실패 로깅 추가**. `/tmp/claude-slack-notify-${WORKTREE}.log` 에 timestamp + event + 실패 사유 기록.
   - python 조립 실패 → "payload assembly failed"
   - curl HTTP non-200 → "slack post failed http=<code>"
   - python stderr → 같은 로그 파일에 그대로 append (`2>>"$LOG_FILE"`)
4. `log_err()` 헬퍼 함수 추가 (반복 코드 제거).

## Verification

- `bash -n slack-notify.sh` → syntax OK
- 백틱·`$`·따옴표 등 특수문자 SUMMARY 로 python 조립 dry-run → JSON 정상 출력, 셸 인젝션 없음
- 가짜 webhook(`http://127.0.0.1:1/dead`) 으로 end-to-end 실행
  - 실제 transcript JSONL 사용
  - 셸 파싱·python 조립·curl 호출 모두 성공
  - `/tmp/claude-slack-notify-claude.log` 에 `slack post failed http=000` 기록 확인
- **사용자 확인 필요**: 다음 응답 종료 시 슬랙 알림 도착 여부, 그리고 실패 시 `/tmp/claude-slack-notify-claude.log` 에 사유가 남는지

## Follow-ups

- 동기 curl 로 바뀌었으므로 webhook 응답이 느리면 Stop 훅이 그만큼 지연된다. settings.json 의 `timeout: 10` 으로 상한이 걸려 있어 최악의 경우도 10초. 슬랙 webhook 은 보통 <500ms 라 실용 영향 없음.
- 로그 파일이 무한 증가할 수 있다. 향후 일정 크기 초과 시 회전 가능.
- 동일 패턴(셸 변수→python heredoc) 의 다른 hook 이 있는지 점검 가치. 현재 알려진 대상 없음.

## Related

- Hook: `.claude/hooks/slack-notify.sh`
- 직전 보고서: `docs/reports/2026-04-19-claude-slack-summary-from-transcript.md`
- Rule: `.claude/rules/security.md` (입력 검증 / 셸 인젝션 방지), `.claude/rules/claude-config-sync.md`
