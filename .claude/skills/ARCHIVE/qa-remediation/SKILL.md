---
name: qa-remediation
description: Regenerate backend/frontend remediation prompts after QA incomplete verdict. Creates standard prompts to send to parallel tabs based on existing QA results or test-reports.
allowed-tools: "Bash Read Glob Grep"
argument-hint: "<slice-name>"
---

# QA Remediation Prompt Generator

Used to (re)generate remediation prompts after QA review gives a "partial" or "incomplete" verdict.

## Usage

```
/qa-remediation slice-06
```

Argument: `$ARGUMENTS`

---

## Purpose

- When `qa-reviewer` already output remediation prompts but they need to be regenerated
- When test-report has remaining blocking items and remediation prompts are needed
- When organizing follow-up work based on previous QA results

---

## Execution Steps

### Step 0: Parse Arguments

Extract slice name from `$ARGUMENTS`.
- If no slice name -> error and abort:
  ```
  Error: Please specify a slice name.
  Usage: /qa-remediation <slice-name>
  Example: /qa-remediation slice-06
  ```

### Step 1: Collect Existing Results

Collect incomplete items for current slice from these sources:

1. **Check test-report**:
   ```bash
   cat test-reports/{slice-name}-test-report.md
   ```
   - If verdict is "Complete" -> inform and exit:
     ```
     Info: {slice-name} already has "Complete" verdict. No remediation needed.
     ```

2. **Check current code state**:
   ```bash
   git status --porcelain
   git log --oneline -5
   ```

3. **Compare against Source of Truth**:
   - `docs/api-contract.md` — verify slice endpoints
   - `docs/domain-model.md` — verify related entities/rules
   - `docs/user-flows.md` — verify related screen flows

### Step 2: Analyze Missing Items

Compare test-report blocking/non-blocking issues against code state:

- Identify **still unresolved items**
- Classify each item as **backend / frontend / qa** area
- Specify reference doc section

### Step 3: Generate Remediation Prompts

Output in the format below. **All sections must be output.**

---

## Output Format

```
## {slice-name} Remediation Prompts

### Current Status
- Verdict: (Partial / Incomplete)
- Blocking issues: N items
- Non-blocking issues: N items

### Unresolved Items

| # | Area | Item | Severity | Status | Reference Doc |
|---|------|------|----------|--------|---------------|
| 1 | backend | ... | blocking | unresolved | api-contract.md §X |
| 2 | frontend | ... | non-blocking | unresolved | user-flows.md §X |

---

### Backend Remediation Prompt

> Paste the following directly into the **backend tab**.

(Complete prompt wrapped in code block)

- If no backend issues:
  ```
  Info: No backend remediation needed. Proceed with frontend only.
  ```

---

### Frontend Remediation Prompt

> Paste the following directly into the **frontend tab**.

(Complete prompt wrapped in code block)

- If no frontend issues:
  ```
  Info: No frontend remediation needed. Proceed with backend only.
  ```

---

### Re-review Prompt

> After remediation is complete, run in the **QA tab**.

(Complete prompt wrapped in code block)

---

### Test Report Update

- After re-review gives "Complete" verdict:
  Run `/slice-test-report {slice-name}` to update final report
```

---

## Remediation Prompt Templates

### Backend Remediation Prompt Template

~~~
## {slice-name} Backend Remediation

### Source of Truth
- docs/api-contract.md
- docs/domain-model.md

### Modification Scope
- Modify only server/. NEVER touch app/.

### Items to Fix
1. (Specific file path + what to change and how)
2. ...

### Agent/Skill to Use
- `backend-builder` agent or direct implementation
- After completion: `cd server && uv run pytest -v --tb=short`

### Verification
- [ ] All pytest pass
- [ ] `/docs-drift-check` -> 0 spec drift
- [ ] `/mvp-slice-check {slice-name}` relevant items pass

### After Completion
- Commit with `/role-scoped-commit-push backend`
- Request re-review in QA tab
~~~

### Frontend Remediation Prompt Template

~~~
## {slice-name} Frontend Remediation

### Source of Truth
- docs/user-flows.md
- docs/api-contract.md

### Modification Scope
- Modify only app/. NEVER touch server/.

### Items to Fix
1. (Specific file path + what to change and how)
2. ...

### Agent/Skill to Use
- `flutter-builder` agent or direct implementation
- After completion: `cd app && flutter test`

### Verification
- [ ] All flutter test pass
- [ ] `/docs-drift-check` -> 0 spec drift
- [ ] `/mvp-slice-check {slice-name}` relevant items pass

### After Completion
- Commit with `/role-scoped-commit-push front`
- Request re-review in QA tab
~~~

### Re-review Prompt Template

~~~
@qa-reviewer {slice-name} re-review.

Previous review found these items as incomplete:
(Quote unresolved items table)

Remediation complete. Re-review focusing on the items above.
Also verify:
- `/smoke-test` results
- `/docs-drift-check` results
If remediation confirmed, change verdict to "complete".
On complete verdict, update `/slice-test-report {slice-name}`.
~~~

---

## Notes

- This skill is **read-only**. It does not modify code.
- Remediation prompts must be wrapped in code blocks for copy-paste.
- If no issues exist in an area, state "no remediation needed". Do not delete the section.
- Always include source of truth document references.
