# Slice Automation & Refinement

## Slice Automation (MVP)

Orchestrator that automatically implements and verifies a single slice:

- `make slice-auto` — auto-detect next slice + plan -> build -> qa -> complete
- `make slice-auto SLICE=slice-07` — run specific slice
- `make slice-status SLICE=slice-07` — check status
- `make slice-resume SLICE=slice-07` — resume after interruption
- `make slice-clean SLICE=slice-07` — clean artifacts

Rules:
- Max 1 auto-retry for remediation. Manual intervention after failure.
- State files: `automation/runs/<slice>/run.json` (compact pointer-based). Logs in separate files.
- backend/frontend run in parallel via git worktrees. No cross-modification between app/ and server/.
- Agent SDK preferred, CLI fallback. Details: `scripts/automation/`

## Refinement Pipeline

User-request-driven feedback loop for UI/UX polish:

- `make refine REQUEST="fix badge spacing"` — inline request
- `make refine REQUEST_FILE=requests/fix.md` — file-based (preferred)
- `make refine REQUEST_FILE=requests/fix.md AUTO_PUSH=1` — with auto-push
- `make refine-status RUN=refine-20260405-001` / `refine-resume` / `refine-clean` / `refine-list`

Flow: analyze -> implement -> verify -> report -> commit -> push.
Max 1 remediation retry. Default: commit+push. Disable with `AUTO_PUSH=0`.
State/artifacts in `automation/runs/refine-*` (gitignored). Details: `scripts/automation/run_refine.py`
