# Slack 알림 요약을 transcript 기반으로 변경

- **Date**: 2026-04-19
- **Worktree (수행)**: `.claude/worktrees/claude`
- **Worktree (영향)**: 모든 워크트리 (다음 rebase 시점에 자동 적용)
- **Role**: claude

## Request

> 슬랙 알람 어떤 작업 했는지 요약하는 부분에 마지막 머지한 내용이 오고있어. 이게 아니라 지금 대화에서 어떤 작업을 너가 진행했는지가 요약해서 나와야 해.

## Root cause / Context

이전 구현은 `git log --since='5 minutes ago'` 결과를 SUMMARY 로 사용했다. PR auto-merge 가 만든 머지 커밋이 5분 윈도우에 항상 들어오므로, "지금 대화에서 무엇을 했는지" 가 아니라 "직전에 머지된 코드 변경" 이 표시되었다. 이는 같은 워크트리에서 connfig 변경·탐색만 한 경우에도 무관한 머지 메시지가 노출되는 부작용이 있었다.

해결: Stop 훅 입력에 포함된 `transcript_path` (Claude Code 표준 필드) 를 읽어 **이번 턴 어시스턴트가 사용자에게 보낸 마지막 텍스트** 를 요약으로 사용한다. 이는 사용자가 화면에서 본 마지막 wrap-up 과 동일하며 항상 "방금 한 일" 을 반영한다.

## Actions

`.claude/hooks/slack-notify.sh` 의 Stop 분기에서 SUMMARY 추출 로직 교체:

1. `transcript_path` 를 INPUT JSON 에서 추출
2. JSONL 을 라인별로 파싱 → 마지막 `type:user` 인덱스 식별
3. 그 이후 `type:assistant` 메시지의 `content` 중 `type:text` 블록만 수집
4. 길이 20자 초과인 substantial text 들 중 **마지막** 을 선택. 없으면 마지막 text. 둘 다 없으면 빈 문자열
5. 개행을 공백으로 평탄화하고 300자로 절단
6. transcript 가 없거나 빈 결과 → `(요약 없음)` fallback

Heredoc 은 single-quoted (`<<'PYEOF'`) 로 변수 보간을 차단하고 `TRANSCRIPT_PATH` 만 env 로 전달하여 인젝션을 방지한다.

git log/diff fallback 은 제거했다. 이전 동작이 사용자 의도와 정반대였기 때문에 의도적으로 폴백 경로에서도 git 정보를 사용하지 않는다.

## Verification

- `bash -n slack-notify.sh` → syntax OK
- 실제 다른 세션의 transcript JSONL 로 파싱 dry-run → 마지막 어시스턴트 wrap-up 텍스트가 정상 추출됨 (300자 이내)
- **사용자 확인 필요**: 다음 응답 종료 시 슬랙 SUMMARY 칸이 머지 커밋이 아니라 이 응답의 wrap-up 으로 표시되는지

## Follow-ups

- transcript 가 매우 길 때(긴 세션)도 한 번의 `open()` + 라인별 파싱으로 처리. 메모리 측면에서 일반 세션 규모(<수 MB) 는 문제 없음. 만약 대규모 transcript 에서 지연이 발생하면 tail 기반 역방향 파싱으로 최적화 여지.
- `(요약 없음)` 이 실제 자주 나타나면 마지막 도구 호출명/카운트로 폴백하는 보강 가능.

## Related

- Hook: `.claude/hooks/slack-notify.sh`
- 이전 보고서: `docs/reports/2026-04-19-claude-slack-notify-repo-name.md`
- Rule: `.claude/rules/claude-config-sync.md`, `.claude/rules/worktree-task-report.md`
