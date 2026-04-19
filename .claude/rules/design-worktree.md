# Design Worktree

The design worktree is the "design studio" for Haeda. Its only job is to produce design documents — UI specs, interaction flows, color palettes, layout diagrams, pixel art specifications — that other worktrees can later implement. It is NOT a place to write, edit, test, build, or deploy code.

## Activation

A worktree becomes a design worktree when `.design-worktree` (an empty, gitignored sentinel file) exists at its repo root. The file is worktree-local.

```bash
# Arm:    touch .design-worktree
# Disarm: rm .design-worktree
```

The dedicated design worktree for this repo is `.claude/worktrees/design` on branch `worktree-design`.

## Hard Boundary

In a design worktree, Write / Edit / NotebookEdit is **blocked** for any path outside `docs/design/**`. This is enforced by `.claude/hooks/design-guard.sh` as a PreToolUse hook — there is no escape hatch.

| Path | Design may edit? |
|------|-------------------|
| `docs/design/**` | yes |
| `app/**`, `server/**` | **no** — code belongs in front/backend worktrees |
| `.claude/**`, `CLAUDE.md` | **no** — config belongs in claude-role worktree |
| `docs/prd.md`, `docs/user-flows.md`, etc. | **no** — source-of-truth docs require user approval |
| `docs/planning/**` | **no** — planning belongs in planner worktree |
| `docs/reports/**`, `impl-log/**`, `test-reports/**` | **no** |

## What the Design Worktree Does

1. Researches design references (web search, image analysis, competitor review).
2. Creates design documents at `docs/design/<slug>.md` — screen layouts, color palettes, pixel art specs, interaction patterns, component breakdowns.
3. Produces detailed enough specs that `ui-designer` and `flutter-builder` agents in a front worktree can implement without ambiguity.
4. Commits and pushes design docs (standard PR-based push; design only ever touches `docs/design/**`, so rebase is trivial).

It does NOT:

- Write Flutter/Dart code, FastAPI code, or any source code.
- Run builders, QA, deployer, or simulators.
- Modify configs, hooks, rules, or skills.
- Touch source-of-truth docs.

## Design Document Structure

Every file under `docs/design/specs/` and `docs/design/drafts/` MUST start with:

```yaml
---
slug: miniroom-cyworld
status: ready        # draft | ready | in-progress | implemented | dropped
created: 2026-04-18
area: front          # front | backend | full-stack
---
```

`status: ready` 는 "완성된 디자인 = **아직 구현 안 됨**" 을 의미한다. 피쳐 워크트리는 이 값을 발견해 자동으로 구현 파이프라인에 태운다.

## Status is Mandatory (Enforced)

`status` 필드는 모든 디자인 스펙에서 **필수**다. `.claude/hooks/design-status-guard.sh` 가 PreToolUse 단계에서 검증한다.

| Status | 의미 | 디자인 워크트리에서 쓸 수 있나? |
|--------|------|-------------------------------|
| `draft` | 작업 중 (보통 `drafts/`) | yes |
| `ready` | 구현 대기 = **아직 구현 안 됨** (보통 `specs/`) | yes |
| `in-progress` | 피쳐 워크트리가 atomic lock 으로 claim | **no** — feature only |
| `implemented` | 구현 완료 | **no** — feature only |
| `dropped` | 폐기 | yes |

디자인 워크트리에서 `in-progress` 또는 `implemented` 로 쓰면 hook 이 exit 2 로 차단한다. 이 두 전환은 피쳐 워크트리가 `/implement-design` 스킬로만 수행한다. `TEMPLATE-*.md` 는 검증 예외다.

## Lifecycle of a Design Spec

```
docs/design/drafts/<slug>.md     status: draft
        |  (iterate, refine in design worktree)
        v
docs/design/specs/<slug>.md      status: ready          ← 디자인 워크트리에서 promote
        |  (피쳐 워크트리에서 /implement-design 실행)
        v
docs/design/specs/<slug>.md      status: in-progress    ← 피쳐 워크트리가 atomic lock
        |  (feature-flow 9-step: implement + QA + deploy)
        v
docs/design/specs/<slug>.md      status: implemented    ← 제자리 유지 (archive 이동 없음)
```

**디자인 스펙은 구현 후에도 제자리에 남는다.** 유지보수·후속 작업의 살아있는 참조 자료이기 때문이다. 기획 문서(`docs/planning/specs/` → `archive/`) 와는 다른 흐름이다.

## Handoff to Implementation

`status: ready` 디자인 스펙은 피쳐 워크트리에서 자동으로 발견되어 구현된다.

```
[피쳐 워크트리]  사용자: "구현 안 된 디자인 찾아서 구현해줘"
        │
        ▼  /implement-design
1. docs/design/specs/*.md 에서 status: ready 인 것을 모음
2. 1개면 자동, 여러 개면 사용자에게 선택 질의
3. 선택한 spec 의 status 를 ready → in-progress 로 atomic flip + PR 머지 (lock)
4. Skill(feature-flow, ...) 호출 — 9-step 파이프라인 실행
5. 성공 시: status 를 in-progress → implemented 로 flip + PR 머지
6. 실패 시: status 를 in-progress 로 남겨두고 보고 (사용자가 진단 후 재시도)
```

자세한 절차는 `.claude/skills/implement-design/SKILL.md` 를 참고한다.

## Related Files

- Enforcement hooks:
  - `.claude/hooks/design-guard.sh` — path-scope guard (디자인 워크트리는 docs/design/ 밖 차단)
  - `.claude/hooks/design-status-guard.sh` — status field guard
  - `.claude/hooks/docs-guard.sh` — source-of-truth guard
- Discovery skill (feature worktree side): `.claude/skills/implement-design/SKILL.md`
- Authoring agent: `.claude/agents/pixel-art-designer.md`
- Templates: `docs/design/TEMPLATE-*.md`
- Worktree role matrix: `.claude/rules/worktree-parallel.md`
- Planner worktree (sibling pattern): `.claude/rules/planner-worktree.md`
