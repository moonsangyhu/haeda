---
name: slice-planning
description: Pre-implementation planning guide for vertical slices. Organizes endpoints, screens, models, and files to implement based on docs. Use before starting slice implementation or when asked to create a plan.
allowed-tools: "Read Glob Grep"
argument-hint: "[slice-name]"
---

# Vertical Slice Planning

Follow this guide to create a plan before starting implementation.
Goal: Identify gaps between docs and code before implementation, and clarify work scope.

## Usage

Call with the slice name:
```
/slice-planning challenge-create
```

## Prerequisites

- **Execute in Plan Mode.** This skill is for planning, not implementation. Verify Plan Mode with Shift+Tab.
- Do not write code until the plan is approved by the user.
- If there are questionable parts in the plan, verify with `spec-keeper` agent before proceeding.

## Planning Steps

### Step 1: Scope Verification

Read the following documents and extract parts relevant to this slice:

1. **docs/prd.md** -> Verify this feature is P0. Stop if P1.
2. **docs/user-flows.md** -> Identify related screen flows
3. **docs/api-contract.md** -> Extract related endpoint list
4. **docs/domain-model.md** -> Extract related entities/fields/business rules

### Step 2: Backend Plan

| Item | Content |
|------|---------|
| Endpoints | METHOD /path — request/response summary for each |
| DB models | Table name, key columns, constraints |
| Service logic | Business rules (domain-model.md §4 reference) |
| Migration | Whether new tables/columns needed |
| File plan | Paths under server/app/ |

### Step 3: Frontend Plan

| Item | Content |
|------|---------|
| Screens | Screen name, which flow in user-flows.md |
| Routing | GoRouter paths |
| API calls | Which endpoints called at what timing |
| Providers | Required Riverpod provider list |
| Models | freezed DTO list |
| File plan | Paths under lib/features/ |

### Step 4: Checkpoint

All questions below must be "yes" before starting implementation:

- [ ] All endpoints are defined in api-contract.md?
- [ ] All entities/fields are defined in domain-model.md?
- [ ] All screens are defined in user-flows.md?
- [ ] No P1 or MVP-excluded features are included?
- [ ] No unresolved items from Open Questions (PRD §9)?

If any answer is "no", confirm with user before implementing.

## Output Format

```
## Slice Plan: {slice name}

### Scope Verification
- P0 status: yes/no
- Related flows: (user-flows.md flow numbers)
- Related endpoints: (list)
- Related entities: (list)

### Backend Plan
(Step 2 table)

### Frontend Plan
(Step 3 table)

### Checkpoint
(Step 4 checklist results)

### Expected Work Order
1. (First task)
2. (Second task)
...

### Verification Plan
- How to prove this slice is complete (pytest scenarios, flutter test targets, smoke test curl commands)
- spec-keeper verification needed: yes/no (reason)
```
