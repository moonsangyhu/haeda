# Feature Report: Deployer Screenshot Capture

- Date: 2026-04-19
- Worktree: claude
- Role: claude
- Area: config (agents, rules, skills)
- Status: complete

## Request

검증 에이전트가 검증 결과 작성 시 앱 스크린샷도 캡처하여 검증 문서와 함께 남기도록 개선.

## Root Cause / Context

기존 deployer는 시뮬레이터에서 앱 실행을 확인하지만 시각적 증거를 저장하지 않았다. 코드 수정 후 요구대로 구현되었는지 눈으로 확인할 수 있는 스크린샷이 필요했다.

## Actions

### Modified Files

| File | Change |
|------|--------|
| `.claude/rules/worktree-parallel.md` | Shared Directories 테이블에 `docs/reports/screenshots/` 등록 |
| `.claude/agents/deployer.md` | Phase 3.5 (Screenshot Capture) 추가 + Output Format에 `### Screenshots` 섹션 |
| `.claude/agents/doc-writer.md` | impl-log, test-report, feature report 3개 템플릿에 스크린샷 참조 추가 |
| `.claude/skills/slice-test-report/SKILL.md` | Report Template에 선택적 Simulator Screenshots 섹션 추가 |

### Key Design Decisions

- 저장 위치: `docs/reports/screenshots/{YYYY-MM-DD}-{role}-{slug}-{NN}.png`
- 캡처 명령: `xcrun simctl io <device-id> screenshot`
- 캡처 수: 2장 (런칭 직후 + 5초 후 settle)
- 실패 처리: non-blocking (캡처 실패해도 deploy verdict 영향 없음)
- git 추적: PNG 파일 추적 (~200-400KB/장)

## Verification

- 4개 파일의 마크다운 구문 및 상대경로 정확성 확인
- worktree-parallel 네이밍 규칙과 일관성 확인
- 실제 동작 검증은 다음 feature/fix 작업의 deployer 실행 시 자동 수행

## Follow-ups

- 다른 워크트리의 기존 세션은 재시작해야 최신 agent 정의가 적용됩니다
- 스크린샷 누적으로 repo 크기가 커지면 `.gitattributes` LFS 규칙 검토

## Related

- Plan: `/Users/yumunsang/.claude/plans/gentle-purring-flask.md`
