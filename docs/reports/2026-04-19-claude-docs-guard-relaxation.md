# docs-guard 유연화 개선

| 항목 | 내용 |
|------|------|
| Date | 2026-04-19 |
| Worktree (수행) | claude |
| Worktree (영향) | 전체 (모든 워크트리에서 docs/ 수정 가능) |
| Role | claude |

## Request

디자인 및 기능구현 시 docs-guard 훅이 문서 수정을 차단하여 작업이 불가능한 문제 해결 요청.

## Root cause / Context

`docs-guard.sh` 훅이 `docs/reports/`, `docs/planning/`, `docs/design/` 외의 모든 `docs/` 파일 수정을 `exit 2`로 차단. 솔로 프로젝트에서 이 수준의 보호는 과도하며, 기능구현 과정에서 API 계약이나 도메인 모델 문서를 함께 업데이트해야 하는 경우가 빈번함.

## Actions

1. `.claude/hooks/docs-guard.sh` — 차단(`exit 2`) → 경고만(`exit 0`)으로 변경. "BLOCKED" → "NOTE" 경고 메시지로 톤 완화.
2. `.claude/rules/docs-protection.md` — "must not be modified" → "자유롭게 수정 가능하되 신중하게" 정책 완화. 대규모 구조 변경만 사용자 사전 고지.
3. `.claude/rules/autonomous-execution.md` — 사용자 허락 필요 예외 테이블에서 docs 항목을 "대규모 구조 변경"으로 한정.

## Verification

- docs-guard.sh 변경 후 `docs/` 하위 파일 수정 시 차단 없이 경고만 출력됨 (exit 0)

## Follow-ups

- 다른 워크트리의 기존 세션은 재시작해야 최신 rule이 완전히 적용됩니다.

## Related

- `.claude/hooks/docs-guard.sh`
- `.claude/rules/docs-protection.md`
- `.claude/rules/autonomous-execution.md`
