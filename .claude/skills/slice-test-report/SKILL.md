---
name: slice-test-report
description: Generate/update test report after slice verification and save to test-reports/. Use after slice implementation, after QA review, or when asked to write a test report.
allowed-tools: "Bash Read Glob Grep Write Edit"
argument-hint: "[slice-name] (e.g., slice-03)"
---

# Slice Test Report

After slice verification is complete, save results as a markdown file in `test-reports/`.
This file is committed to git and serves as evidence for regression checks and progress history.

## Usage

```
/slice-test-report slice-03
/slice-test-report slice-04 --update    # update existing file
```

## Core Principles

1. **Record only actual execution results.** Run tests directly and write based on actual output.
2. **Distinguish estimates from measurements.** Mark items not directly verified as `[unverified]`.
3. **Do not hide failures.** Record failed tests as-is.
4. **Use "all tests pass" only with execution evidence.** Cite passed/failed counts from pytest/flutter test output.

## Execution Steps

### Step 1: Run Tests

Execute the following commands in order and collect results:

```bash
# Backend tests
cd server && .venv/bin/python -m pytest -v 2>&1

# Flutter tests
cd app && flutter test 2>&1
```

### Step 2: Verify Slice Scope

Extract endpoints, screens, and error codes relevant to this slice from the 4 docs.

### Step 3: Write/Update Report

- New slice: Create `test-reports/{slice-name}-test-report.md`
- Re-verification: Update test result section and date of existing file

### Step 4: Add Local Smoke Test Results (optional)

If smoke test was run or results already exist, fill in that section.
If not run, mark as `[not run]`.

## File Naming

```
test-reports/{slice-name}-test-report.md
```

Examples:
- `test-reports/slice-01-test-report.md`
- `test-reports/slice-03-test-report.md`

## Report Template

Follow this structure. Fill every section without omission.

```markdown
# {slice-name} Test Report

> Last updated: {YYYY-MM-DD}
> Verdict: **Complete** / **Partial** / **Incomplete**

## Slice Overview

| Item | Content |
|------|---------|
| Slice | {name} |
| Goal | {one-line description} |
| Related Flow | user-flows.md Flow {N} |
| P0 | P0 |

## Implementation Scope

### Backend Endpoints

| Endpoint | Status | Notes |
|----------|--------|-------|
| {METHOD /path} | Implemented / Not implemented | |

### Frontend Screens

| Screen | Route | Status |
|--------|-------|--------|
| {screen name} | {/path} | Implemented / Not implemented |

## Test Results

### Backend Tests

Command: `cd server && .venv/bin/python -m pytest tests/{file} -v`

| Test | Result | Notes |
|------|--------|-------|
| {test_name} | PASS / FAIL | |

**Summary**: {N} passed, {M} failed (citing pytest output)

### Frontend Tests

Command: `cd app && flutter test test/{path}`

| Test | Result | Notes |
|------|--------|-------|
| {test_name} | PASS / FAIL | |

**Summary**: {N} passed, {M} failed (citing flutter test output)

### Local Smoke Test

| Item | Result | Method |
|------|--------|--------|
| {endpoint or flow} | PASS / FAIL / [not run] | curl / browser / [unverified] |

### Simulator Screenshots

(Include only if deployer captured screenshots for this slice. Omit section if none.)

| Screenshot | Path | Notes |
|-----------|------|-------|
| Launch | `docs/reports/screenshots/{YYYY-MM-DD}-{role}-{slug}-01.png` | |
| Settled | `docs/reports/screenshots/{YYYY-MM-DD}-{role}-{slug}-02.png` | |

## Verification Distinction

### Actually Verified
- (Items directly executed and verified)

### Unverified / Estimated
- (Items not directly verified due to environment limitations, including estimation basis)

## Issues

### Blocking
- (Describe if any, otherwise "None")

### Non-blocking
- (Describe if any, otherwise "None")

## Verdict

- **Slice complete**: Complete / Partial / Incomplete
- **Can proceed to next slice**: Yes / No
- **Reason**: (One-line verdict rationale)
```

## Notes

- Do not modify source of truth documents in `docs/`.
- Reports are saved only in `test-reports/`.
- Do not write reports without running tests.
- Reference previous slice reports but do not copy their content.
