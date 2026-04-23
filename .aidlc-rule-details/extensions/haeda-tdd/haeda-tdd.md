# Haeda TDD Extension (ALWAYS-ENFORCED)

## Overview

All production code changes in this project MUST follow a Test-Driven Development cycle: RED → GREEN → REFACTOR. This is a hard constraint applied during AIDLC's **Construction → Code Generation** stage and verified at **Construction → Build and Test**.

**Enforcement**: Non-compliance is a **blocking finding**. The Code Generation stage MUST NOT present its "Continue to Next Stage" option until every production-code change has cited RED (failing test) and GREEN (passing test) evidence.

## Scope

**In scope** (TDD mandatory):
- `server/app/routers/**` — FastAPI routers
- `server/app/services/**` — service / business-logic layer
- `server/app/models/**` + Alembic migration files
- `app/lib/features/**` — Flutter feature screens, providers, widgets
- `app/lib/core/**` — shared utilities
- Any other production code generated under `app/` or `server/`

**Out of scope** (TDD exceptions, allowed without a failing test first):
- Test files themselves (`server/tests/**`, `app/test/**`)
- Typo / formatting / comment changes
- Config defaults, `.env.example` entries
- `.aidlc-rule-details/**`, `aidlc-docs/**`, `docs/**`, `.claude/**` — not production code
- Dependency version bumps with no code change

## Rule TDD-01: Write the failing test first (RED)

**Rule**: Before writing or modifying any in-scope production code, author (or identify) a test that exercises the target behavior and confirm that it fails for the expected reason.

**Verification**:
- The Code Generation plan file includes a RED step that creates or modifies a test file
- The test execution output shows the target test FAILING with an assertion or import error that confirms the behavior under test is not yet implemented
- The failure is NOT a generic "syntax error in test" — it must fail because the production behavior is missing
- The RED command + first ~10 lines of its output appear in the Code Generation stage completion summary (and in `aidlc-docs/construction/{unit}/code/` summary)

## Rule TDD-02: Make the test pass with the minimum code change (GREEN)

**Rule**: After RED, implement the smallest code change that makes the new/changed test pass. Re-run the test(s) to confirm a full pass.

**Verification**:
- The Code Generation output cites a GREEN command + pass count (e.g., `pytest server/tests/test_foo.py` → `3 passed in 0.42s`)
- No unrelated tests are broken (full suite, or at minimum the affected package, MUST pass)
- The diff between RED and GREEN touches only production code relevant to that test. Incidental refactoring belongs in a separate REFACTOR step.

## Rule TDD-03: Refactor with tests green (REFACTOR, optional but logged)

**Rule**: After GREEN, if the code needs structural cleanup, perform it while keeping the tests green. Re-run tests after every non-trivial edit.

**Verification**:
- If refactoring occurred, the Code Generation output notes the change and re-quotes the pass count
- If no refactoring was needed, the output explicitly states "REFACTOR: none — code shape adequate"

## Rule TDD-04: Evidence format in stage summary

Every Code Generation stage completion message MUST include, for each unit's production-code change, a `### TDD Cycle Evidence` block structured as:

```markdown
### TDD Cycle Evidence

- **RED**:
  - Command: `cd server && pytest tests/test_challenge.py::test_create_challenge_requires_title -x`
  - Output (excerpt):
    ```
    FAILED tests/test_challenge.py::test_create_challenge_requires_title - assert 500 == 422
    1 failed in 0.38s
    ```
- **GREEN**:
  - Command: `cd server && pytest tests/test_challenge.py -v`
  - Output (excerpt):
    ```
    tests/test_challenge.py::test_create_challenge_requires_title PASSED
    tests/test_challenge.py::test_create_challenge_ok PASSED
    2 passed in 0.41s
    ```
- **REFACTOR**: none — route and schema already minimal.
```

Placeholders such as "tests will pass" or "output to be verified" are **not accepted** — cite actual output.

## Rule TDD-05: Forbidden shortcuts

The following patterns are blocking findings:
- Writing production code before any failing test exists for it
- Commenting out or skipping a failing test instead of fixing production code (`@pytest.mark.skip`, `skip: true`, etc., without a linked ticket)
- Citing GREEN output that was not actually executed in this session
- Asserting "TDD followed" without the RED + GREEN blocks above

## Interaction with Other AIDLC Stages

- **Functional Design / NFR Design**: MAY describe the testing strategy (unit vs integration, fixtures, test data) but do not themselves run tests.
- **Code Generation Part 1 (Planning)**: MUST list RED → GREEN → REFACTOR checkboxes per production-code change.
- **Code Generation Part 2 (Generation)**: MUST execute and cite the RED then GREEN commands.
- **Build and Test stage**: MUST re-run the relevant test suite as part of its verification and cite the aggregate pass count.

## Compliance Summary Format (in stage completion message)

```
## Extension Compliance — haeda-tdd
- TDD-01 Failing test first: compliant — RED cited for `test_create_challenge_requires_title`
- TDD-02 Minimum GREEN change: compliant — 2 passed, no collateral failures
- TDD-03 Refactor log: N/A — no refactor needed
- TDD-04 Evidence format: compliant
- TDD-05 Forbidden shortcuts: compliant — no skipped tests, no unverified claims
```
