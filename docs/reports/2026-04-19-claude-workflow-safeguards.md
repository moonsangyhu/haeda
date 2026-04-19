# Feature Report: 워크플로우 미완료 방지 안전장치

- Date: 2026-04-19
- Worktree: claude
- Role: claude
- Area: config (skills, hooks, agents)
- Status: complete

## Request

feature 워크트리에서 기능 구현 후: (1) 시뮬레이터에 앱 미실행, (2) 파일 미커밋 문제의 근본 원인 분석 및 개선.

## Root Cause / Context

feature-flow 파이프라인이 중간에 중단되었으나(세션 종료/타임아웃), 이를 감지하거나 경고하는 안전장치가 없었다. 또한 front 워크트리에서 server/ 파일도 수정하는 cross-role 위반이 커밋 시점이 아닌 구현 시점에서 감지되지 않았다.

## Actions

### 1. feature-flow 미완료 복구 가이드 (feature-flow/SKILL.md)
- Guardrails 끝에 "미완료 복구" 섹션 추가
- 세션 시작 시 staged/unstaged 변경 자동 감지 스크립트
- 마지막 완료 Step 식별표 + 재개 절차

### 2. Stop hook — uncommitted-warn.sh (신규)
- 세션 종료 시 미커밋 변경 감지하여 경고 출력
- `~/.claude/settings.json` Stop hook에 등록

### 3. builder cross-role 조기 감지 (flutter-builder.md, backend-builder.md)
- Phase 2.5 추가: 구현 완료 후 상대 role 파일 수정 여부 체크
- flutter-builder: `server/` 감지 → STOP + Backend Handoff 섹션
- backend-builder: `app/` 감지 → STOP + Frontend Handoff 섹션

## QA Results

- 구조적 검증: feature-flow 미완료 복구표가 모든 케이스 커버하는지 확인
- uncommitted-warn.sh chmod +x 확인
- settings.json Stop hook 등록 확인

## Follow-ups

- 다른 워크트리 세션 재시작 필요
- feature 워크트리의 55개 staged 파일은 사용자가 직접 처리 필요 (commit 또는 reset)

## Related

- 이전: 2026-04-19-claude-pr-based-push.md
