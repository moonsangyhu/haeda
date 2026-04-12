---
name: plan-feature
description: In the planner worktree, shape a feature idea into a ready-to-implement spec at docs/planning/specs/<slug>.md. Use when the user describes an idea to bank for later.
allowed-tools: "Read Write Edit Glob Grep Bash"
argument-hint: "[slug] [short description]"
---

# Plan Feature

Authoring helper for the planner worktree. Turns a user-described idea into a filled-out spec using `docs/planning/TEMPLATE.md` and commits it.

## Preconditions

- Current worktree MUST be a planner worktree (`.planner-worktree` sentinel at repo root). If not, STOP and tell the user to run this from the planner worktree.
- `docs/planning/TEMPLATE.md` must exist.

## Usage

```
/plan-feature verification-reminder "push notification nudge when user hasn't verified today"
/plan-feature                # no args — ask user for slug + description via AskUserQuestion
```

Argument: `$ARGUMENTS` (first token = slug, rest = description).

---

## Execution Steps

### 1. Verify planner worktree

```bash
test -f .planner-worktree || { echo "STOP: not a planner worktree"; exit 1; }
```

### 2. Gather inputs

If `$ARGUMENTS` is empty, use AskUserQuestion to collect:
- slug (lowercase-hyphenated, max 40 chars)
- one-sentence description
- area (front / backend / full-stack)
- priority (P0 / P1 / P2)

If a slug was given, check `docs/planning/specs/<slug>.md` and `docs/planning/ideas/<slug>.md` — if either exists, ask the user whether to overwrite, edit, or pick a new slug.

### 3. Read source-of-truth context (read-only)

Before drafting, read the parts of these files that look relevant to the idea:
- `docs/prd.md` — scope + priority context
- `docs/user-flows.md` — screens/flows the feature touches
- `docs/domain-model.md` — entities that would change
- `docs/api-contract.md` — endpoints that would change

Do NOT edit any of these. They are source-of-truth.

### 4. Draft the spec

Copy `docs/planning/TEMPLATE.md` to `docs/planning/specs/<slug>.md`. **20년차 앱 기획 전문가의 관점**으로 모든 섹션을 작성한다. 다음 품질 기준을 적용:

**페르소나 & 톤**:
- 사장님께 바로 보고할 수 있는 수준의 문서를 작성한다
- 구체적이고 설득력 있는 근거 중심 서술. 추상적 표현 금지
- 정량적 수치를 가능한 한 포함 (추정치라도 근거와 함께 제시)

**유저 시나리오 (섹션 3)**:
- 최소 2개의 페르소나 기반 시나리오. 각 시나리오에 이름, 나이, 직업, 동기 부여
- 행동 흐름은 스크린 단위로 구체적으로 (탭, 스와이프, 표시되는 UI 요소 명시)
- 감정 변화 포함 — 사용 전 frustration → 사용 후 satisfaction 같은 arc
- Happy path + 최소 1개의 edge case 시나리오

**기획 의도 (섹션 4)**:
- "왜 이 기능이 지금 필요한가"에 대한 전략적 답변
- 최소 2개의 대안을 검토하고 현재 안을 선택한 이유 설명
- MVP 목표, 파일럿 성공 조건과의 연결

**기대 효과 (섹션 5)**:
- 정량적 KPI 최소 2개 (현재 추정치 → 기대 변화, 측정 방법 포함)
- 정성적 효과 3가지 이상
- 리스크 최소 1개와 완화 방안

**품질 게이트**: 작성 후 자체 검토 — "이 문서를 경영진에게 바로 보여줄 수 있는가?" 기준 미달이면 다시 작성.

기존 규칙 유지:
- Front-matter `status: ready` only if every section is filled AND there are no blocking open questions. Otherwise use `status: idea` and save to `docs/planning/ideas/<slug>.md` instead.
- 섹션 8의 API/domain deltas는 구체적 docs 섹션 인용. 해당 파일 수정 금지 — 필요한 변경만 명시.
- Acceptance criteria는 testable해야 한다.
- Open questions는 비어있거나 한 문장으로 답변 가능해야 한다.

### 5. Show the draft

**기획서 전문을 출력**한다 (요약이 아닌 전체 내용). 사용자가 품질을 직접 확인할 수 있어야 한다.

출력 후 묻는다: "저장할까요? (save / edit / cancel)"

- save → proceed to step 6
- edit → apply the user's edits and reshow
- cancel → delete the draft file, stop

### 6. Commit and push

Only if the user said "save":

```bash
git add docs/planning/specs/<slug>.md   # or docs/planning/ideas/<slug>.md
git commit -m "plan(<slug>): add feature spec"
# rebase-retry push (see .claude/rules/worktree-parallel.md)
git fetch origin main
git rebase origin/main || { git rebase --abort; echo "rebase conflict — STOP"; exit 1; }
git push origin HEAD:main
```

Report the commit SHA and the path to the new spec.

## Post-conditions

- Spec exists at `docs/planning/specs/<slug>.md` (or `ideas/<slug>.md`) with valid front-matter.
- Commit is on `origin/main`.
- User is told how to implement it later: "In a feature worktree, run `/implement-planned` to pick this up."
