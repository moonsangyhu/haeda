# 디자인 워크트리 핸드오프 안내 정정 (front → feature)

- **Date**: 2026-04-20
- **Worktree (수행)**: `.claude/worktrees/claude` (role: claude)
- **Worktree (영향)**: `design`, `feature`, `front`, `backend` 워크트리 — 다음 세션부터 적용
- **Role**: claude

## Request

사용자가 디자인 워크트리에서 작업을 마치면 디자인 에이전트가 "프론트 워크트리에서 `/implement-design` 실행하면 이 스펙이 자동 발견되어 … 파이프라인에 태워집니다" 식으로 안내한다고 보고. 사용자는 front/backend 분리 없이 **feature 워크트리 한 곳**에서 full-stack 을 구현하는 정책을 쓰는데 안내가 잘못되어 있음. "단도리" 요청.

## Root cause / Context

두 층위의 불일치:

1. **문서 문구**: `.claude/rules/design-worktree.md` 가 두 군데에서 "front worktree" 로만 핸드오프를 안내 (L23, L33). 이 rule 을 읽은 디자인 쪽 에이전트/세션이 그대로 "프론트 워크트리" 문구를 재생성.
2. **실제 차단 로직(더 심각)**: `flutter-builder` / `backend-builder` 에이전트의 Phase 0 worktree gate 가 `front*|slice-*-front|fix-*-front` 만 허용해서, feature 워크트리에서 `/implement-design` → `feature-flow` 를 돌리면 빌더가 즉시 `ERROR: not in a front worktree (got: feature)` 로 STOP 했다. 상위 `.claude/rules/worktree-parallel.md` §Agent Responsibilities (L198-200) 는 이미 "`front` or `feature`-role" 을 허용한다고 명시되어 있지만 개별 에이전트 구현이 따라오지 못한 상태.

즉 문구만 고쳐서는 사용자가 올바르게 feature 워크트리에서 돌려도 파이프라인이 터졌다.

## Actions

5개 파일을 한 PR 로 수정.

1. `.claude/rules/design-worktree.md`
   - L23 path 표: `code belongs in front/backend worktrees` → `code belongs in feature 워크트리(솔로 개발 기본) 또는 front/backend 분리 워크트리`
   - L33 What-the-design-worktree-does: "front worktree" 핸드오프 대상을 feature 기준으로 재작성. 핸드오프 안내 문구 작성 규칙("프론트 워크트리에서..." X, "feature 워크트리에서..." O) 을 명시해 미래 디자인 세션의 문구 표류를 차단.

2. `.claude/agents/flutter-builder.md` Phase 0
   - L25 문구: `front`-role → `feature`- or `front`-role, 솔로 기본은 feature 임을 명시
   - L29-32 case 패턴: `feature|feature-*|slice-[0-9]*|front*|slice-*-front|fix-*-front` 허용

3. `.claude/agents/backend-builder.md`
   - L24, L28-31: flutter-builder 와 같은 패턴 확장
   - Phase 2.5 Cross-Role File Check (L69-82): feature 워크트리에서는 `app/` 수정이 합법이므로 `app/` 차단 블록을 skip. 분리 워크트리에서만 enforcement 유지. Frontend Handoff 섹션 사용도 분리 워크트리 한정으로 표현을 명확화.

4. `.claude/agents/debugger.md`
   - L44-49 역할 표에 `feature` row 신규 추가 (`app/**`, `server/**` 양쪽 편집 가능). feature 워크트리는 cross-layer 버그도 handoff spec 없이 단일 워크트리에서 완결 처리.

5. `.claude/hooks/design-guard.sh` L36 차단 메시지
   - `Code edits belong in backend/front worktrees` → `Code edits belong in feature worktree (or backend/front split worktrees)`

건드리지 않은 항목 (의도적):
- `docs/design/specs/*.md` 내 "front 워크트리" 문구 — 개별 스펙은 역사 기록이고 claude role 은 `docs/design/` 편집 권한 없음
- `.claude/rules/worktree-parallel.md` — 이미 `front or feature` 로 올바름
- `.claude/skills/implement-design/SKILL.md` — 이미 feature/front/backend 허용
- `.claude/hooks/planner-guard.sh` — planner 쪽 유사 문구, 이번 요청 범위 밖

## Verification

worktree-name 별 gate 시뮬레이션 (`bash case` 패턴 수동 실행):

| 워크트리 이름 | flutter-builder gate | backend-builder gate | backend Phase 2.5 app/ check |
|--------------|---------------------|---------------------|------------------------------|
| `feature` | PASS ✅ | PASS ✅ | SKIP (의도) ✅ |
| `backend` | — | PASS ✅ | ACTIVE (의도) ✅ |
| `qa-slice-07` | REJECT ✅ | — | — |

결과: feature 워크트리는 두 빌더 모두 통과하고 cross-role 블록이 비활성화됨. 분리 backend 는 기존대로 `app/` 수정 차단이 유지됨. qa 등 관계 없는 역할은 여전히 빌더 gate 에서 거부됨.

실전 검증은 사용자가 다음에 `.claude/worktrees/feature` 에서 `/implement-design` 을 실행할 때 자연스럽게 이루어짐 (Phase 0 통과 여부 로그).

## Follow-ups

- **⚠️ 다른 워크트리의 기존 세션은 재시작해야 최신 rule/agent 가 완전히 적용된다.** 특히 이미 돌고 있는 feature / design / front / backend 워크트리 세션이 있다면 종료 후 새 세션을 열어야 함 (`.claude/rules/claude-config-sync.md` §4).
- 향후 `docs/design/TEMPLATE-*.md` 가 새로 만들어질 때 "feature 워크트리 기준" 문구를 기본으로 채택해야 함. 현재는 템플릿 부재.
- `.claude/agents/pixel-art-designer.md` 가 `.claude/rules/design-worktree.md` L114 에서 참조되지만 실제 파일이 없음 (dangling reference). 사용자의 이번 요청 범위 밖이라 손대지 않았으나 추후 정리 대상.
- 개별 `docs/design/specs/*.md` (예: `challenge-room-speech.md`, `room-decoration.md`, `challenge-room-social.md`) 의 "front 워크트리" 표현은 유지. 새 스펙 작성 시 상위 rule 이 feature 기준으로 안내하므로 표현이 자연스럽게 수렴할 것.

## Related

- Plan: `/Users/yumunsang/.claude/plans/stateful-leaping-milner.md`
- Rule (base contract): `.claude/rules/worktree-parallel.md` §Worktree Role Contract, §Agent Responsibilities
- Rule (propagation): `.claude/rules/claude-config-sync.md`
- Rule (task report): `.claude/rules/worktree-task-report.md`
- 이전 관련 보고서:
  - `docs/reports/2026-04-19-claude-design-status-enforce.md` (design status field 강제)
  - `docs/reports/2026-04-19-claude-workflow-safeguards.md` (cross-role 위반 감지)
