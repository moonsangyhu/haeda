---
name: implement-design
description: In a feature worktree, find an unimplemented design spec (status: ready) in docs/design/specs/ and hand it to the feature-flow pipeline. Use when the user says "구현 안 된 디자인 찾아서 구현해줘", "디자인 문서 구현해줘", "implement next design", or similar.
allowed-tools: "Read Write Edit Glob Grep Bash Skill"
argument-hint: "[slug]"
---

# Implement Design Spec

Feature-worktree-side consumer of the design spec library. Picks a `status: ready` spec from `docs/design/specs/`, atomically locks it as `in-progress`, hands it to `feature-flow` for full implementation, then flips to `implemented` on success. Mirror of `/implement-planned` but design specs **stay in place** after completion (no archive move) — they are living references for future maintenance.

## Preconditions

- Current worktree MUST NOT be the design worktree (`.design-worktree` sentinel MUST be absent).
- Current worktree MUST NOT be the planner worktree (`.planner-worktree` sentinel MUST be absent).
- Current worktree SHOULD be `feature`, `front`, or `backend` role.
- `docs/design/specs/` must contain at least one `*.md` file with `status: ready`.

## Usage

```
/implement-design                          # list ready specs, pick one
/implement-design miniroom-cyworld         # implement this specific slug
```

Argument: `$ARGUMENTS` (optional slug).

---

## Execution Steps

### 1. Refuse to run in design or planner worktree

```bash
if [ -f .design-worktree ]; then
  echo "STOP: this is a design worktree. Switch to a feature/front/backend worktree (e.g. .claude/worktrees/feature) and rerun."
  exit 1
fi
if [ -f .planner-worktree ]; then
  echo "STOP: this is a planner worktree. Switch to a feature/front/backend worktree and rerun."
  exit 1
fi
```

### 2. Sync with origin

```bash
git fetch origin main
git rebase origin/main || { echo "rebase conflict — invoke /resolve-conflict"; exit 1; }
```

If rebase fails, follow `.claude/skills/resolve-conflict/SKILL.md` before continuing.

### 3. Collect ready specs

Glob `docs/design/specs/*.md` (skip `TEMPLATE-*.md` if any leak in, skip `.gitkeep`). For each file, read the YAML front-matter and keep only those with `status: ready`. Extract:

- `slug`
- `type` (item | screen | component | animation | other)
- `target-agent` (flutter-builder | backend-builder | both — if missing, infer from `area`)
- `area` (front | backend | full-stack — if present)
- The first H1 heading (display title)
- `depends-on` list (warn the user if any dependency slug is itself still `ready` or `in-progress`)

If `$ARGUMENTS` is provided:

- Match the given slug exactly. If no match, STOP and list what IS ready. If the match exists but its status is not `ready`, STOP and report the actual status.

If no argument:

- If exactly one ready spec exists → use it automatically.
- If multiple → use AskUserQuestion. Sort by `created` ascending (oldest first), then by slug.
- If zero → STOP with message: "No ready design specs in `docs/design/specs/`. Author one in the design worktree first (`cd .claude/worktrees/design && claude`)."

### 4. Resolve open questions before locking

If the spec contains an "Open Questions" / "열린 질문" section with unresolved bullets, STOP and ask the user to answer before proceeding. Do not guess answers during implementation.

### 5. Atomic lock — flip status to `in-progress`

Edit the spec's front-matter: `status: ready` → `status: in-progress`. Then commit and push via PR (do **not** push directly to main):

```bash
SLUG="<chosen-slug>"
git add "docs/design/specs/${SLUG}.md"
git commit -m "design(${SLUG}): mark in-progress"

# push_via_pr per .claude/rules/worktree-parallel.md §PR-Based Push
BRANCH=$(git branch --show-current)
git fetch origin main
git rebase origin/main || { echo "rebase conflict — invoke /resolve-conflict"; exit 1; }
git push origin "$BRANCH" --force-with-lease
gh pr create --base main --head "$BRANCH" \
  --title "design(${SLUG}): in-progress" \
  --body "원자적 락. /implement-design 자동 생성." 2>/dev/null || true
PR=$(gh pr view "$BRANCH" --json number -q .number)
gh pr merge "$PR" --merge --delete-branch=false || { echo "auto-merge failed — STOP"; exit 1; }
git fetch origin main && git rebase origin/main
```

This claim is a lightweight lock — other worktrees won't pick the same spec mid-flight. The lock survives even if the implementation crashes (status remains `in-progress` until step 7 or manual intervention).

### 6. Hand off to feature-flow

Read the spec body. Build a feature-flow input by concatenating the spec title (H1) and the salient implementation sections — typically:

- Visual identity / 시각적 설명
- Pixel grid spec / 픽셀 그리드 스펙
- Color palette / 색상 팔레트
- Layer / positioning / 레이어
- ASCII art (if present)
- flutter-builder / backend-builder 구현 노트

Append a synthetic acceptance criterion: "QA verifies visual implementation matches the spec." Then invoke:

```
Skill(feature-flow, "<title>\n\n<rendered sections>\n\nDesign spec source: docs/design/specs/<slug>.md")
```

`feature-flow` runs the standard 9-step pipeline. Do NOT bypass any step. Steps include product-planner → spec-keeper → builders → code-review → QA → deploy → doc-writer → commit.

### 7. On success — flip to `implemented`

After feature-flow reports completion (deploy success + commit pushed), flip the status. **Do not move the file to archive** — design specs are living references.

```bash
SLUG="<chosen-slug>"
# In-place edit: status: in-progress → status: implemented
git add "docs/design/specs/${SLUG}.md"
git commit -m "design(${SLUG}): mark implemented"

# push_via_pr (same pattern as step 5)
BRANCH=$(git branch --show-current)
git fetch origin main
git rebase origin/main
git push origin "$BRANCH" --force-with-lease
gh pr create --base main --head "$BRANCH" \
  --title "design(${SLUG}): implemented" \
  --body "구현 완료 표시. /implement-design 자동 생성." 2>/dev/null || true
PR=$(gh pr view "$BRANCH" --json number -q .number)
gh pr merge "$PR" --merge --delete-branch=false
git fetch origin main && git rebase origin/main
```

Then write a pointer in `impl-log/design-${SLUG}-${ROLE}.md` (where `${ROLE}` is the worktree role: feature/front/backend) referencing `docs/design/specs/${SLUG}.md` as the originating spec.

### 8. On failure — leave the lock

If feature-flow fails at any stage (build, QA, deploy, doc), do NOT flip to `implemented`. The spec stays at `status: in-progress` so the user can diagnose, fix, and retry. Report which stage failed and surface the relevant log path.

The user may manually flip back to `ready` to release the lock if they decide to abandon the attempt.

## Notes

- The `design-status-guard.sh` hook validates every status write. It allows feature worktrees (no `.design-worktree` sentinel) to write `in-progress` and `implemented`, but blocks the design worktree from doing so. This skill therefore can only run from the correct worktree.
- Rebase conflicts during status flips usually mean two workers raced for the same spec. STOP and ask the user — never `--force` past it.
- Do not run this skill while another `/implement-design` is mid-flight in the same worktree. Single-track per worktree.
- `feature` role 워크트리에서는 같은 slug 의 front+backend 작업이 한 워크트리에서 같이 진행되므로 추가 분기 불필요.

## Related

- Mirror: `.claude/skills/implement-planned/SKILL.md` (planning-side counterpart, archives on done)
- Hook: `.claude/hooks/design-status-guard.sh`
- Rule: `.claude/rules/design-worktree.md`
- Rule: `.claude/rules/worktree-parallel.md` §PR-Based Push (push_via_pr definition)
- Skill: `.claude/skills/resolve-conflict/SKILL.md` (rebase conflict handler)
