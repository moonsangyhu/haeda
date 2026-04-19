# feature role 추가 및 워크트리 전략 현실화

| 항목 | 내용 |
|------|------|
| Date | 2026-04-19 |
| Worktree (수행) | claude |
| Worktree (영향) | feature, 전체 |
| Role | claude |

## Request

feature 워크트리에서 프론트+백엔드를 함께 개발하는 현행 방식에 대한 검토 및 개선.

## Root cause / Context

기존 worktree-parallel.md에 `feature` role이 정의되어 있지 않아, feature 워크트리가 role contract를 위반하는 상태였음. 외부 사례 조사 결과 솔로 개발에서 레이어(front/back) 분리는 오버헤드만 증가시키며, 기능 단위 full-stack 작업이 업계 표준임을 확인.

## Actions

1. `.claude/rules/worktree-parallel.md`
   - `feature` role 추가: `app/**` + `server/**` 동시 접근 허용
   - shared directory role 목록에 `feature` 추가
   - agent responsibilities에서 builder들이 `feature` role에서도 실행 가능하도록 완화
   - 레이어 분리 대신 기능 단위 분리 근거 명시

2. `.claude/rules/agents.md`
   - implementation dispatch에서 feature role 워크트리 순차 실행 허용 명시

## Verification

- worktree-parallel.md의 role contract에 `feature` role이 정상 등록됨
- builder agent가 feature role 워크트리에서 실행 가능하도록 제약 완화됨

## Follow-ups

- 다른 워크트리의 기존 세션은 재시작해야 최신 rule이 완전히 적용됩니다.
- 기존 `backend-*`, `front-*` role은 향후 팀 확장 시를 위해 유지 (삭제하지 않음)

## Related

- `.claude/rules/worktree-parallel.md`
- `.claude/rules/agents.md`
- `docs/reports/2026-04-19-claude-docs-guard-relaxation.md`
