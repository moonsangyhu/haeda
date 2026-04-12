# 2026-04-12 · claude · attention-hook

- **Date**: 2026-04-12
- **Worktree (수행)**: `claude`
- **Worktree (영향)**: 전체 (user-level `~/.claude/` 변경이므로 동일 macOS 사용자의 모든 Claude Code 세션에 공통 적용)
- **Role**: claude

## Request

> https://www.stdy.blog/1p1w-03-attention-hook/ 를 보고 나도 이 클로드 알람 오는 기능을 사용하고 싶어. 검토해서 도입 가능하다면 계획해서 실행해줘

사용자가 Claude Code 가 주의를 필요로 하는 순간(권한 승인 대기, idle, 턴 종료)에 macOS 네이티브 알림을 받고 싶다고 요청.

## Context

Claude Code 는 두 hook event 로 이 기능을 커버할 수 있다 (공식 docs: https://code.claude.com/docs/en/hooks):

| Event | 트리거 | Matcher |
|------|------|---------|
| `Notification` | 권한 승인 요청 / idle / MCP elicitation | `permission_prompt`, `idle_prompt`, `elicitation_dialog` |
| `Stop` | 턴 응답 완료 | 없음 (항상) |

현재 상태에서는 `~/.claude/settings.json` 에 `hooks` 항목이 없었고, 프로젝트 `.claude/settings.json` 의 `hooks` 도 비어 있었다. 병렬 worktree 환경이라 **개인 생산성 설정은 user-level 에 두고** 프로젝트 git-tracked 설정은 건드리지 않는 방향으로 결정 (`.claude/rules/claude-config-sync.md` 의 전파 부담 회피).

## Actions

### 1. 알림 스크립트 생성 — `~/.claude/hooks/notify.sh`

- bash + `python3` (JSON 파싱) + `osascript` (macOS 내장 알림) 조합. 외부 의존성 없음.
- stdin 으로 들어오는 payload 에서 `hook_event_name`, `notification_type`, `message`, `cwd` 파싱.
- 이벤트별 제목/사운드 분기:
  - `Notification` + `permission_prompt` → "Claude needs permission" / `Sosumi`
  - `Notification` + `idle_prompt` → "Claude is idle" / `Ping`
  - `Notification` + `elicitation_dialog` → "Claude requests input" / `Funk`
  - `Notification` + 기타 → "Claude notification" / `Pop`
  - `Stop` → "Claude finished" / `Glass`
- `subtitle` 에 현재 워크트리 basename 표시(`claude`, `slice-04-backend` 등) — 병렬 세션 구분용.
- fire-and-forget: 모든 실패는 무시하고 `exit 0`, stdout 에 `{}` 출력.
- `chmod +x` 로 실행 권한 부여.

### 2. `~/.claude/settings.json` 에 hook 등록

기존 키(`skipDangerousModePermissionPrompt`, `statusLine`)는 보존하고 `hooks` 객체 추가:

```json
"hooks": {
  "Notification": [
    {
      "matcher": "permission_prompt|idle_prompt|elicitation_dialog",
      "hooks": [
        { "type": "command", "command": "/Users/yumunsang/.claude/hooks/notify.sh", "timeout": 5 }
      ]
    }
  ],
  "Stop": [
    {
      "hooks": [
        { "type": "command", "command": "/Users/yumunsang/.claude/hooks/notify.sh", "timeout": 5 }
      ]
    }
  ]
}
```

하나의 스크립트가 두 이벤트를 모두 처리하고 payload 내부 `hook_event_name` 으로 분기.

### 3. 프로젝트 파일은 건드리지 않음

- `.claude/settings.json`, `.claude/hooks/*` 등 git-tracked 파일은 수정 없음.
- 본 보고서만 git 에 남음 (worktree-task-report 규칙).

## Verification

1. **JSON 유효성**: `python3 -m json.tool ~/.claude/settings.json` → valid.
2. **스크립트 실행 권한**: `ls -l ~/.claude/hooks/notify.sh` → `-rwxr-xr-x`.
3. **스크립트 단독 실행 (권한 이벤트)**:
   ```bash
   echo '{"hook_event_name":"Notification","notification_type":"permission_prompt","message":"test permission","cwd":"/Users/yumunsang/haeda/.claude/worktrees/claude"}' | ~/.claude/hooks/notify.sh
   ```
   → exit 0, stdout `{}`, macOS 알림 발송 호출 (osascript 경로 통과).
4. **스크립트 단독 실행 (Stop 이벤트)**:
   ```bash
   echo '{"hook_event_name":"Stop","cwd":"/Users/yumunsang/haeda/.claude/worktrees/claude"}' | ~/.claude/hooks/notify.sh
   ```
   → exit 0, stdout `{}`, 정상.
5. **실제 Claude Code 세션에서의 확인**: 새 세션에서 자동 로드. **사용자 확인 필요 항목**:
   - [ ] 새 세션 시작 후 임의 질문에 응답이 끝날 때 "Claude finished / Glass" 알림 수신
   - [ ] macOS 시스템 설정 → 알림 → Script Editor(osascript) 권한 허용 상태 확인
   - [ ] permission_prompt 가 뜨는 상황에서 "Claude needs permission / Sosumi" 알림 수신

## Follow-ups

- ⚠️ **기존 Claude Code 세션은 재시작 필요**: `~/.claude/settings.json` 변경은 새 세션부터 적용된다. 현재 실행 중인 backend/front/qa/claude 세션은 모두 재시작해야 알림이 뜬다.
- macOS 전용 구현. Linux/Windows 환경에서는 동작 안 함 (현재 사용자 환경이 macOS 이므로 문제 없음).
- 잠금 화면 알림 미리보기가 켜져 있을 경우 `message` 에 커맨드 일부가 노출될 수 있음 → 필요 시 macOS 시스템 설정 → 알림 → "잠금 화면에서 미리보기 숨김" 권장.
- 추후 `Stop` 이벤트 필터링이 필요하면 (예: 1초 이내 종료는 스킵) 스크립트에 duration 기반 스킵 로직 추가 가능.

## Related

- 계획: `~/.claude/plans/snoopy-foraging-scott.md`
- 공식 docs: https://code.claude.com/docs/en/hooks
- 블로그 원문: https://www.stdy.blog/1p1w-03-attention-hook/
- 참고 레퍼런스: https://alexop.dev/posts/claude-code-notification-hooks/
- 관련 규칙: `.claude/rules/claude-config-sync.md`, `.claude/rules/worktree-task-report.md`
