---
name: next-slice-planning
description: Recommend the next slice based on completed slices and docs source of truth, and generate 3 parallel tab prompts for backend/frontend/qa.
allowed-tools: "Bash Read Glob Grep"
argument-hint: "[current-slice-name]"
---

# Next Slice Planning

After QA completion or independently, recommend the next slice to work on
and generate prompts ready to paste into parallel tabs (backend/frontend/qa).

## Usage

```
/next-slice-planning slice-06
/next-slice-planning            # omit current slice to auto-detect latest completed
```

Argument: `$ARGUMENTS`

---

## Execution Steps

### Step 0: Parse Arguments

Extract current slice name from `$ARGUMENTS`.
- If omitted, auto-detect the most recently completed slice from `test-reports/` directory.

### Step 1: Assess Completion Status

1. **Read test-reports**:
   ```bash
   ls test-reports/
   ```
   Read each report to check verdict (complete/partial/incomplete).

2. **Check code state**:
   ```bash
   ls server/app/routers/
   ls app/lib/features/
   ```
   Verify actually implemented endpoints and screens.

3. **Completed slices summary**:
   ```
   | Slice | Verdict | Key Content |
   |-------|---------|-------------|
   | slice-03 | Complete | ... |
   | slice-04 | Complete | ... |
   | ...   |         |             |
   ```

### Step 2: Identify Unimplemented P0 Items

Read the following docs and extract still-unimplemented P0 items:

1. **docs/prd.md** — unimplemented items from P0 feature list
2. **docs/api-contract.md** — P0 endpoints without routers yet
3. **docs/user-flows.md** — P0 flows without screens yet
4. **docs/domain-model.md** — P0 entities without models yet

### Step 3: Determine Next Slice

Selection rules:
1. **Respect order**: If a prior slice is incomplete (including partial), do not skip it. Recommend completing it first.
2. **Dependencies**: Only recommend slices whose dependent endpoints/models are already complete.
3. **P0 only**: Never recommend P1 features.
4. **Single recommendation**: Default is 1. May mention runner-up candidate in one line.
5. **All P0 complete**: Output "All MVP P0 features are implemented." and exit.

### Step 4: Generate Prompts

---

## Output Format

```
## Next Slice Recommendation

### Completion Status

| Slice | Verdict | Key Content |
|-------|---------|-------------|
| ... | ... | ... |

### Unimplemented P0 Items

| # | Area | Item | Reference Doc |
|---|------|------|---------------|
| 1 | ... | ... | ... |

---

### Recommendation: {next-slice-name}

| Item | Content |
|------|---------|
| Goal | (one-line summary) |
| P0 reference | prd.md §X |
| Dependent slices | (or "none") |

#### Included Scope

- Endpoints: (from api-contract.md)
- Screens: (from user-flows.md)
- Entities/rules: (from domain-model.md)

#### Excluded Scope

- (Items not included in this slice)

#### Runner-up Candidate

- (One line if any, otherwise "none")

---

### Backend Tab Prompt

> Paste the following directly into the **backend tab**.

(Code block)

---

### Frontend Tab Prompt

> Paste the following directly into the **frontend tab**.

(Code block)

---

### QA Tab Prompt

> After backend/frontend completion, run in the **QA tab**.

(Code block)
```

---

## Tab Prompt Templates

### Backend Tab Prompt

~~~
## {next-slice-name} Backend Implementation

### Prerequisites
- Enter Plan Mode (Shift+Tab)
- Run `/slice-planning {next-slice-name}` to create plan
- Verify plan with `@spec-keeper`
- Start implementation after plan approval

### Source of Truth
- docs/api-contract.md — endpoints, request/response, error codes
- docs/domain-model.md — entities, fields, business rules

### Goal
(Specific backend work summary)

### Endpoints to Implement
1. METHOD /path — description
2. ...

### Modification Scope
- Modify only server/. NEVER touch app/.
- (Expected file paths)

### Agent/Skill to Use
- `backend-builder` agent or direct implementation
- Rules: `.claude/skills/fastapi-mvp/`

### Verification
- [ ] `cd server && uv run pytest -v --tb=short` all pass
- [ ] `/docs-drift-check` -> 0 spec drift
- [ ] `/mvp-slice-check {next-slice-name}` backend items pass

### After Completion
- Commit with `/role-scoped-commit-push backend`
- Request review in QA tab
~~~

### Frontend Tab Prompt

~~~
## {next-slice-name} Frontend Implementation

### Prerequisites
- Enter Plan Mode (Shift+Tab)
- Run `/slice-planning {next-slice-name}` to create plan
- Verify plan with `@spec-keeper`
- Start implementation after plan approval

### Source of Truth
- docs/user-flows.md — screen flows, UI structure
- docs/api-contract.md — endpoint request/response

### Goal
(Specific frontend work summary)

### Screens/Widgets to Implement
1. Screen name — user-flows.md Flow N reference
2. ...

### Modification Scope
- Modify only app/. NEVER touch server/.
- (Expected file paths)

### Agent/Skill to Use
- `flutter-builder` agent or direct implementation
- Rules: `.claude/skills/flutter-mvp/`

### Verification
- [ ] `cd app && flutter test` all pass
- [ ] `/docs-drift-check` -> 0 spec drift
- [ ] `/mvp-slice-check {next-slice-name}` frontend items pass

### After Completion
- Commit with `/role-scoped-commit-push front`
- Request review in QA tab
~~~

### QA Tab Prompt

~~~
@qa-reviewer {next-slice-name} review.

Slice goal:
(One-line goal)

Included scope:
(Endpoints, screens, entities list)

Review in this order:
1. Run `/mvp-slice-check {next-slice-name}`
2. Run `/docs-drift-check`
3. Run `cd server && uv run pytest -v --tb=short`
4. Run `cd app && flutter test`
5. Run `/smoke-test`
6. Perform checklist-based review
7. Output verdict

On complete verdict, run `/slice-test-report {next-slice-name}` to save report.
~~~

---

## Notes

- This skill is **read-only**. It does not modify code.
- Never recommend P1 features.
- Never recommend skipping an incomplete slice.
- Never recommend endpoints/screens/entities not in docs.
- Prompts must be wrapped in code blocks for copy-paste.
