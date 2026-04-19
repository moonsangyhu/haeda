# Slack 알림에 레포 이름 추가

- **Date**: 2026-04-19
- **Worktree (수행)**: `.claude/worktrees/claude`
- **Worktree (영향)**: 모든 워크트리(claude / feature / backend / front / qa). 다른 워크트리는 다음 rebase 시 `.claude/hooks/slack-notify.sh` 동기화 후 적용.
- **Role**: claude

## Request

> 슬랙 알람 보낼 때 어떤 레포지토리에서 보내는지도 같이 표시해 줘

여러 프로젝트에서 Claude Code 를 동시에 돌릴 때 슬랙 알림이 어느 레포에서 온 것인지 구분되지 않는 문제 해결 요청.

## Root cause / Context

기존 `.claude/hooks/slack-notify.sh` 는 메시지 헤더에 워크트리 디렉터리 basename(`claude`, `feature`) 만 포함했다. 동일 워크트리명을 다른 레포에서 사용할 가능성, 그리고 다중 프로젝트 환경에서 알림 출처를 즉시 식별할 수 없는 점이 한계였다.

## Actions

`.claude/hooks/slack-notify.sh` 수정 (단일 파일 변경):

1. **REPO 변수 추출 추가** (L23–27)
   - 1차: `git remote get-url origin` 결과를 sed 로 파싱해 `.git` 제거 + 경로/콜론 뒤 마지막 토큰 추출 → `haeda`
   - 폴백: `git rev-parse --git-common-dir` 의 부모 디렉터리 basename. 워크트리에서도 메인 레포 `.git` 을 가리키므로 안전.
   - 둘 다 실패 시 `unknown`.
2. **Stop 메시지 헤더 변경** (L72–75)
   - `repo` 변수 추가 + `header_id = repo + '/' + worktree if repo and repo != worktree else worktree`
   - 표시: `:white_check_mark: *작업 완료* — \`haeda/claude\``
3. **Notification 메시지 헤더 변경** (L119–122)
   - 동일한 `header_id` 패턴 적용
   - 표시: `:bell: *결정 필요* — \`haeda/claude\``

`repo == worktree` 인 메인 레포 직접 작업 시 `haeda/haeda` 같은 중복 표시를 회피한다.

## Verification

- `bash -n slack-notify.sh` → syntax OK
- `git remote get-url origin | sed ...` 로컬 실행 → `haeda` 출력 확인
- Python `header_id` 분기 로직 로컬 실행:
  - `repo=haeda, worktree=claude` → `haeda/claude` ✅
  - `repo=haeda, worktree=haeda` → `haeda` ✅
  - `repo='', worktree=feature` → `feature` ✅ (폴백이 unknown 일 때 워크트리만 표시)
- **사용자 확인 필요**: 이 응답 종료 시 Stop 훅이 발사되어 슬랙에 `*작업 완료* — \`haeda/claude\`` 형태로 도착하는지.

## Follow-ups

- 다른 워크트리(`feature`, `backend`, `front`, `qa`) 의 기존 세션은 Claude Code 의 hook 캐시가 세션 시작 시 로드되므로, 다음 사용자 메시지부터 자동으로 갱신된 hook 을 사용한다(파일 시스템상 rebase 만 되면 됨). 명시적 세션 재시작 불필요 — hook 은 매 호출마다 디스크에서 읽힌다.
- claude-config-sync 규칙에 따라 본 변경은 즉시 PR-merge 한다.

## Related

- Plan: `~/.claude/plans/virtual-wobbling-squid.md`
- Hook file: `.claude/hooks/slack-notify.sh`
- Rule: `.claude/rules/claude-config-sync.md`, `.claude/rules/worktree-task-report.md`
