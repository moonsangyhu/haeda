# Slack 알림 훅 구현

| 항목 | 내용 |
|------|------|
| Date | 2026-04-19 |
| Worktree (수행) | claude |
| Worktree (영향) | 전체 (모든 워크트리에서 알림 발송) |
| Role | claude |

## Request

각 워크트리에서 작업 완료 또는 결정 필요 시 Slack 채널로 알림 발송.

## Root cause / Context

병렬 워크트리 운영 시 사용자가 각 세션의 상태를 능동적으로 확인해야 하는 불편. 외부 사례 조사 결과 Stop/Notification 훅 + Slack Webhook 조합이 표준 패턴임을 확인.

## Actions

1. `.claude/hooks/slack-notify.sh` 생성
   - `Stop` 이벤트: 작업 완료 알림 (워크트리명 포함)
   - `Notification` 이벤트: 결정 필요 알림 (유형 + 메시지 포함)
   - `stop_hook_active` 체크로 무한루프 방지
   - `SLACK_WEBHOOK_URL` 환경변수 미설정 시 조용히 스킵
   - curl을 백그라운드로 실행하여 Claude 응답 지연 방지
   - timeout 10초 설정

2. `.claude/settings.json` — Stop, Notification 훅 등록

## Verification

- 스크립트 실행 권한 부여 (`chmod +x`)
- settings.json에 Stop/Notification 훅 정상 등록

## Follow-ups

- 사용자가 `SLACK_WEBHOOK_URL` 환경변수를 설정해야 알림이 실제로 발송됨
  - Slack App → Incoming Webhooks → Add New Webhook to Workspace → 채널 선택
  - `~/.zshrc`에 `export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T.../B.../..."` 추가
- 다른 워크트리의 기존 세션은 재시작해야 최신 훅이 적용됩니다

## Related

- `.claude/hooks/slack-notify.sh`
- `.claude/settings.json`
- 참고: https://api.slack.com/messaging/webhooks
