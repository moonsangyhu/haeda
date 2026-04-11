---
name: set
description: Configure Claude Code settings, agents, skills, rules, and hooks. Reviews changes with user before applying, then commits and pushes.
user_invocable: true
disable_model_invocation: true
---

# Set — Claude Configuration Management

Manage `.claude/` configuration files (settings, agents, skills, rules, hooks).

Argument: `<what to configure>` — natural language description of the desired change.

---

## Step 1: Analyze Request

Determine which configuration area is affected:

| Area | Files | Examples |
|------|-------|---------|
| **settings** | `.claude/settings.json` | permissions, hooks, plugins, statusLine |
| **agents** | `.claude/agents/*.md` | model, maxTurns, skills, role description |
| **skills** | `.claude/skills/*/SKILL.md` | new skill, modify existing skill |
| **rules** | `.claude/rules/*.md` | path-scoped rules (server-guard, app-guard) |
| **hooks** | `.claude/hooks/*.py` | pre/post hooks for workflow enforcement |
| **CLAUDE.md** | `CLAUDE.md` | project-level rules and workflow |

Read the relevant existing files to understand current state.

## Step 2: Propose Changes

Print a clear before/after summary:

```
## Configuration Change Proposal

### Area
{settings / agents / skills / rules / hooks / CLAUDE.md}

### Files to Modify
- {file path} — {what changes}

### Before
{current relevant content, abbreviated}

### After
{proposed new content, abbreviated}

### Impact
{what this change affects in practice}
```

**STOP and ask the user for approval.** Do not apply changes without confirmation.

## Step 3: Apply Changes

After user approval, apply the changes using Edit or Write tools.

### Validation
- **settings.json**: Verify valid JSON after edit
- **agents**: Verify frontmatter (name, description, model, maxTurns, skills)
- **skills**: Verify frontmatter (name, description, user_invocable)
- **rules**: Verify path-scoping comment if applicable

## Step 4: Commit & Push

Invoke the `/commit` skill to stage, commit, and push the changes.

If `/commit` is unavailable, manually — ALWAYS via rebase-retry (see `.claude/rules/worktree-parallel.md`):
```bash
git add <changed files>
git commit -m "chore(claude): <description>

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"

for attempt in 1 2 3; do
  git fetch origin main
  git rebase origin/main || { git rebase --abort; echo "rebase conflict"; exit 1; }
  git push origin HEAD:main && break
  sleep 1
done
```

## Step 5: Summary

```
## Configuration Updated

| Item | Value |
|------|-------|
| Area | {area} |
| Files | {file list} |
| Change | {one-line summary} |
| Commit | {hash} |
| Push | done |
```

---

## Guardrails

- **User approval required**: Always show proposed changes and get confirmation before applying
- **No source code changes**: This skill only modifies `.claude/` and `CLAUDE.md`
- **Backup awareness**: Print current content before overwriting
- **Valid format**: Ensure JSON/YAML/Markdown remains valid after edit
