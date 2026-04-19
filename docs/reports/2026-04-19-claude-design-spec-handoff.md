# Feature Report: Design Spec Handoff to Feature Pipeline

- Date: 2026-04-19
- Worktree: claude
- Role: claude
- Area: config (agents, skills)
- Status: complete

## Request

디자인 워크트리에서 만든 기획서를 피쳐 워크트리에서 읽지 못하는 문제 해결.

## Root Cause / Context

파일 동기화(rebase) 자체는 정상 작동한다. 문제는 파이프라인의 어떤 에이전트도 `docs/design/`을 읽으라는 지시가 없었기 때문에, 파일이 디스크에 있어도 에이전트가 찾지 못했다.

플래닝 스펙(`docs/planning/specs/`)은 `/implement-planned` 스킬이 명시적으로 스캔하므로 작동했지만, 디자인 스펙(`docs/design/`)은 이런 연결고리가 없었다.

## Actions

### Modified Files

| File | Change |
|------|--------|
| `.claude/skills/feature-flow/SKILL.md` | Step 0에 `docs/design/` 스캔 + 디자인 스펙 컨텍스트를 product-planner에 주입하는 절차 추가 |
| `.claude/agents/product-planner.md` | Design Specs 섹션 추가 — 디자인 스펙을 선택적 입력으로 인식, Spec References에 design spec 항목 추가 |
| `.claude/agents/flutter-builder.md` | Phase 1 Context Discovery에 `docs/design/` 확인 단계 추가 |

### Design Decision

디자인 스펙을 별도 스킬(`/implement-design`)로 만들지 않고, 기존 `feature-flow` 파이프라인에 통합했다. 이유:
- 디자인 스펙은 독립 실행 단위가 아니라 기능 구현의 입력 컨텍스트
- Main(Opus)이 Step 0에서 디자인 스펙을 읽어 product-planner에 전달하면, 이후 체인은 자연스럽게 디자인 의도를 반영
- flutter-builder도 직접 `docs/design/` 확인 가능하여 이중 안전망

## Verification

- 구조적 검증: feature-flow Step 0 → product-planner → flutter-builder 순서로 디자인 컨텍스트 전파 경로 확인
- 실제 검증은 다음 디자인 스펙 기반 feature-flow 실행 시 수행

## Follow-ups

- 다른 워크트리의 기존 세션은 재시작해야 최신 agent 정의 적용
- `docs/design/` 스펙이 많아지면 키워드 매칭보다 front-matter의 `slug`/`area` 기반 필터링 강화 검토

## Related

- 이전 작업: 2026-04-19-claude-deployer-screenshot-capture.md
