---
name: skill-creator
description: Create new skills, modify and improve existing skills. Use when users want to create a skill from scratch, edit an existing skill, or optimize a skill's description for better triggering.
user_invocable: true
---

# Skill Creator

A skill for creating new skills and iteratively improving them.

## Process

1. **Capture intent** — understand what the skill should do, when it triggers, expected output
2. **Draft the SKILL.md** — write the skill following the structure below
3. **Test** — run 2-3 realistic test prompts to verify behavior
4. **Iterate** — improve based on results
5. **Commit** — use `/commit` to save and push

## Skill Structure

```
skill-name/
├── SKILL.md (required)
│   ├── YAML frontmatter (name, description, user_invocable)
│   └── Markdown instructions
└── Optional bundled resources
    ├── scripts/    - Executable code
    ├── references/ - Docs loaded as needed
    └── assets/     - Templates, icons, etc.
```

## SKILL.md Frontmatter

```yaml
---
name: skill-name
description: When to trigger + what it does. Be specific and slightly "pushy" to ensure triggering.
user_invocable: true   # true if user calls it with /skill-name
disable_model_invocation: true  # optional: only trigger via slash command
---
```

## Writing Guidelines

### Description Field (Critical for Triggering)
The description is the PRIMARY mechanism for whether Claude invokes the skill. Include:
- What the skill does
- Specific contexts/phrases that should trigger it
- Be slightly "pushy" — Claude tends to under-trigger skills

### Instruction Body
- Use imperative form ("Read the file", not "You should read the file")
- Explain **why** things are important, not just what to do
- Avoid excessive MUST/NEVER/ALWAYS — explain reasoning instead
- Keep under 500 lines; use bundled reference files for overflow
- Include examples where helpful

### Progressive Disclosure
1. **Metadata** (name + description) — always in context (~100 words)
2. **SKILL.md body** — loaded when skill triggers
3. **Bundled resources** — loaded on demand via Read tool

## Step-by-Step: Creating a New Skill

### 1. Interview
Ask the user:
- What should this skill enable Claude to do?
- When should it trigger? (phrases, contexts)
- What's the expected output format?
- Are there edge cases to handle?

### 2. Draft
Write `SKILL.md` with frontmatter + instructions. Place in `.claude/skills/<name>/SKILL.md`.

### 3. Test
Create 2-3 realistic test prompts and run them mentally or in conversation to verify the skill would produce correct behavior.

### 4. Iterate
Based on test results:
- Generalize from specific feedback (don't overfit to examples)
- Keep instructions lean — remove what doesn't pull its weight
- Explain the "why" behind instructions

### 5. Save
Use `/commit` to stage, commit, and push the new skill.

## Modifying Existing Skills

1. Read the current skill: `.claude/skills/<name>/SKILL.md`
2. Understand what needs to change
3. Apply minimal edits (don't rewrite what works)
4. Test the change
5. Use `/commit` to save

## Haeda Project Context

Skills in this project live at `.claude/skills/`. Existing skills:
- `feature-flow` — enforced feature workflow (8 steps)
- `fix` — lightweight bug fix flow
- `commit` — quick commit & push
- `set` — Claude configuration management
- `local` — Docker environment management
- `smoke-test` — integration testing
- And more (slice-planning, qa-remediation, etc.)

When creating skills for this project, follow existing patterns and ensure compatibility with the agent team (backend-builder, flutter-builder, qa-reviewer).
